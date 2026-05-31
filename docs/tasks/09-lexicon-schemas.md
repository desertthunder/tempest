---
title: Milestone 09 - Lexicon Schemas
specs:
  - ../specs/lexicon-schemas.md
---

Completed [May 8, 2026](../../CHANGELOG.md#2026-05-08).

## Verification

```bash
mix tempest.lexicon.generate --source ../atproto/lexicons --commit <commit>
mix test test/tempest/lexicon
hurl --test --jobs 1 --variable base_url=http://localhost:4000 test/smoke/lexicon-schemas.hurl
```

The smoke test verifies known-schema validation, configured resolver behavior,
optimistic unknown-schema writes, and strict validation failure.
