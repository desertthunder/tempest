---
title: Milestone 09 - Lexicon Schemas
specs:
  - ../specs/lexicon-schemas.md
---

Goal: load, generate, resolve, and manage known Lexicon schemas without hardcoding application schemas in validation logic.

## Tasks

- [ ] T09-01: Define Lexicon registry behaviour and document provider boundary.
- [ ] T09-02: Add generic Lexicon document validation, including duplicate ids, duplicate refs, and loader limits.
- [ ] T09-03: Add deterministic Lexicon manifest format with source repo, commit, generated timestamp, counts, and document ids.
- [ ] T09-04: Add generator task for pinned atproto `lexicons/` input.
- [ ] T09-05: Generate bundled known-schema data for selected record schemas and wire it into the runtime registry.
- [ ] T09-06: Add operator-configured local Lexicon directory support with startup validation.
- [ ] T09-07: Preserve record-write validation modes: known `valid`, optimistic unknown, strict unknown failure, and explicit validation skip.
- [ ] T09-08: Add tests for refs, unions, ref cycles, deep refs, oversized schemas, duplicate ids, and duplicate refs.
- [ ] T09-09: Document external Lexicon resolution policy, default configuration, and source precedence.
- [ ] T09-10: Add external resolver interface behind an explicit config flag.
- [ ] T09-11: Implement NSID authority resolution through DNS/DID/PDS `com.atproto.lexicon.schema` records.
- [ ] T09-12: Add SSRF, redirect, timeout, response-size, address-range, and recursion protections for the external resolver.
- [ ] T09-13: Add positive, negative, stale, and single-flight cache behavior for externally resolved schemas.
- [ ] T09-14: Ensure externally resolved schemas cannot override bundled or configured local schemas unless explicitly allowed.
- [ ] T09-15: Add compatibility tests against official atproto profile/post/follow record schemas.
- [ ] T09-16: Add resolver tests for disabled, unknown, success, cache hit, negative cache, oversized response, and private-address rejection paths.
- [ ] T09-17: Document operator schema update workflow and add Hurl smoke tests for generated, resolved, and unknown schema behavior.

## Integration Tests

- Generated profile schema validates a profile record.
- Unknown schema with validation unset stores successfully as `unknown`.
- Unknown schema with `validate: true` fails.
- Configured local custom schema validates a custom record.
- Duplicate schema ids fail startup or generation.
- Externally resolved custom schema validates when resolver config permits it.
- External resolver failures return `unknown` in optimistic mode and fail when `validate: true`.
- External resolver refuses private/local network targets and oversized schema responses.

## CLI Verification

```bash
mix tempest.lexicon.generate --source ../atproto/lexicons --commit <commit>
mix test test/tempest/lexicon
```

## HTTP Verification

```bash
hurl --test --jobs 1 --variable base_url=http://localhost:4000 test/smoke/lexicon-schemas.hurl
```

Expected:

- Known generated schema returns `validationStatus: "valid"`.
- Configured external schema resolver returns `validationStatus: "valid"` for a resolvable schema.
- Unknown schema with validation unset returns `validationStatus: "unknown"`.
- Unknown schema with `validate: true` returns `InvalidRequest`.
