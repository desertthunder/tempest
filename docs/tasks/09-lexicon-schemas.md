---
title: Milestone 09 - Lexicon Schemas
specs:
  - ../specs/lexicon-schemas.md
---

Goal: load, generate, and manage known Lexicon schemas without hardcoding application schemas in validation logic.

## Tasks

- [ ] T09-01: Define Lexicon registry behaviour and document provider boundary.
- [ ] T09-02: Add generic Lexicon document shape validation.
- [ ] T09-03: Add duplicate document id and duplicate definition-ref checks.
- [ ] T09-04: Add deterministic Lexicon manifest format.
- [ ] T09-05: Add generator task for pinned atproto `lexicons/` input.
- [ ] T09-06: Emit source metadata: repo, commit, generated timestamp, and document count.
- [ ] T09-07: Generate bundled known-schema data for selected record schemas.
- [ ] T09-08: Wire generated schemas into the runtime registry.
- [ ] T09-09: Add operator-configured local Lexicon directory support.
- [ ] T09-10: Add startup validation for configured Lexicon directories.
- [ ] T09-11: Add tests for known schema `valid` status.
- [ ] T09-12: Add tests for unknown schema with validation unset returning `unknown`.
- [ ] T09-13: Add tests for unknown schema with `validate: true` failing.
- [ ] T09-14: Add tests for ref cycles, deep refs, oversized schemas, and duplicate ids.
- [ ] T09-15: Document external Lexicon resolution policy before implementing network fetches.
- [ ] T09-16: Add optional external resolver interface behind a disabled-by-default config flag.
- [ ] T09-17: Add SSRF and response-size protections for the external resolver.
- [ ] T09-18: Add cache metadata for externally resolved schemas.
- [ ] T09-19: Add compatibility test against official atproto profile/post/follow record schemas.
- [ ] T09-20: Document schema update workflow for operators.
- [ ] T09-21: Add Hurl smoke test for generated and unknown schema validation behavior.

## Integration Tests

- Generated profile schema validates a profile record.
- Unknown schema with validation unset stores successfully as `unknown`.
- Unknown schema with `validate: true` fails.
- Configured local custom schema validates a custom record.
- Duplicate schema ids fail startup or generation.

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
- Unknown schema with validation unset returns `validationStatus: "unknown"`.
- Unknown schema with `validate: true` returns `InvalidRequest`.
