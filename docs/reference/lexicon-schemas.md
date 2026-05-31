---
title: Lexicon Schemas
updated: 2026-05-31
---

Lexicons describe AT Protocol schemas: XRPC methods, record shapes, object types,
refs, unions, and primitive constraints. Tempest uses Lexicons to validate record
writes without hardcoding application schemas in validator code.

## Concepts

A collection such as `app.bsky.actor.profile` is also a Lexicon NSID. A record's
`$type` should match its collection. If the PDS knows the schema, it can validate
fields and rkey rules before committing the record.

Unknown schemas are possible in an open protocol. Clients can ask for strict
validation; otherwise a PDS may accept unknown records while marking validation
status as unknown.

## Implementation

Tempest separates three concerns:

- schema engine: validates Lexicon documents and record values generically
- registry: answers whether a schema is known and trusted
- sources: bundled generated schemas, local configured schemas, and explicitly
  enabled external resolution

Bundled schemas are generated from a pinned atproto Lexicon checkout and include
source metadata. Operators can configure local schema files for custom apps.
External resolution is behind policy controls and uses cache, timeout, redirect,
response-size, recursion, and private-address protections.

## Record validation behavior

For record writes:

- known schema + validation enabled: validate and return `valid`
- unknown schema + `validate: true`: reject with `InvalidRequest`
- unknown schema + validation unset: accept and return `unknown`
- `validate: false`: skip schema validation after generic safety checks

Generic safety checks still apply: `$type`, collection NSID, rkey syntax, record
size, CBOR limits, and repo write authorization.

## Operator workflow

Regenerate bundled schemas from a pinned source when updating the known atproto
Lexicon set. Local schemas should fail startup/generation if they contain invalid
or duplicate IDs.

## Verification

```bash
mix tempest.lexicon.generate --source ../atproto/lexicons --commit <commit>
mix test test/tempest/lexicon
hurl --test --jobs 1 --variable base_url=http://localhost:4000 test/smoke/lexicon-schemas.hurl
```
