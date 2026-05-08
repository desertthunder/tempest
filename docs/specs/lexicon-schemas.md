---
title: Lexicon Schema Loading and Generation
updated: 2026-05-07
---

Tempest needs generic Lexicon validation without baking application schemas into validator code. Record APIs should validate known schemas, tolerate unknown schemas when the request permits it, and give operators a reproducible way to update the known schema set.

## Reference Implementation Baseline

The TypeScript reference PDS does not dynamically resolve arbitrary record Lexicons today.

Observed behavior:

- Canonical `com.atproto.*`, `app.bsky.*`, `chat.bsky.*`, and related Lexicons live in the atproto repository under `lexicons/`.
- Generated TypeScript modules expose those Lexicons to PDS code.
- Repo write preparation keeps a `knownSchemas` map of selected record schemas.
- `validateRecord` uses that map:
  - `validate: false` skips schema validation.
  - known `$type` validates the rkey and record body against the schema.
  - unknown `$type` with `validate: true` fails.
  - unknown `$type` with `validate` unset returns `validationStatus: "unknown"`.
- The reference implementation has an explicit TODO to replace the static known schema map with automatically fetched and built schemas.

Sources checked:

- `packages/pds/src/repo/prepare.ts`
- `packages/pds/src/api/com/atproto/repo/createRecord.ts`
- `packages/lexicon/src/lexicons.ts`
- `packages/lexicon/src/validators/complex.ts`
- `packages/lexicon/src/validators/primitives.ts`

## Tempest Design

Tempest should keep three concerns separate:

1. Lexicon schema engine: generic validation of documents, definitions, refs, unions, objects, arrays, and primitive constraints.
2. Lexicon registry: lookup boundary for known Lexicon documents.
3. Lexicon sources: bundled, generated, configured, or externally resolved schema documents.

The schema engine must not contain product- or app-specific schemas. Bluesky Lexicons can be used in tests and can be bundled as generated artifacts, but they should remain data, not branches in validator code.

## Known Schema Sources

Tempest should support these sources in order:

- Bundled generated schemas from an explicit atproto source commit.
- Operator-configured local schema files for custom applications.
- Later: external Lexicon resolution and caching once a resolution policy exists.

Bundled schemas should include metadata:

```text
source_repo
source_commit
generated_at
document_count
document_ids
```

## Generation Pipeline

The generator should:

1. Read Lexicon JSON files from a pinned checkout or vendored source directory.
2. Validate each Lexicon document shape.
3. Normalize and index definition refs.
4. Emit deterministic Elixir data or an efficient serialized manifest.
5. Record source metadata.
6. Fail on duplicate document ids or duplicate definition refs.
7. Exclude unrelated files.

Generated output must be reproducible from the same source commit.

## External Resolution

External resolution is future work and must be policy-driven.

Open policy decisions:

- Which NSID authorities can be resolved.
- Whether resolution uses DNS, HTTPS well-known paths, PLC metadata, or another mechanism.
- How to verify schema authorship.
- Cache TTL and invalidation.
- Whether a PDS should allow writes using externally resolved schemas by default.
- How to protect against SSRF, oversized schemas, deep refs, and dependency cycles.

Until those decisions are implemented, unknown schemas should follow the reference behavior: accepted as `unknown` unless `validate: true`.

## Validation Semantics

For record writes:

- `$type` must match `collection`.
- If a known record schema exists, validate rkey against the record key schema.
- If a known record schema exists and validation is not disabled, validate the record body.
- If no schema exists and `validate: true`, reject with `InvalidRequest`.
- If no schema exists and validation is unset, return `validationStatus: "unknown"`.
- If `validate: false`, skip schema validation and omit or return unknown validation status according to endpoint compatibility needs.

## Adversarial Checks

- A schema cannot define refs that escape loader limits or create unbounded recursion.
- External schema fetches must not reach private or local addresses.
- A generated schema bundle must be tied to a source commit so compatibility regressions are explainable.
- Unknown Lexicon records cannot bypass generic record safety checks such as `$type`, collection NSID, record key syntax, record size, and CBOR limits.
- A malicious configured Lexicon must not crash validation or exhaust CPU/memory.

## HTTP Verification

Record API verification remains the black-box check:

```bash
http POST :4000/xrpc/com.atproto.repo.createRecord \
  "Authorization:Bearer $TOKEN" \
  repo=alice.test collection=app.bsky.actor.profile rkey=self \
  record:='{"$type":"app.bsky.actor.profile","displayName":"Alice"}'
```

Expected with bundled/generated profile schema:

- Response includes `validationStatus: "valid"`.

Expected for unknown schema with validation unset:

- Record can be created and response includes `validationStatus: "unknown"`.

Expected for unknown schema with `validate: true`:

- Request fails with `InvalidRequest`.
