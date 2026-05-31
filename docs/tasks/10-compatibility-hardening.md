---
title: Milestone 10 - Compatibility Hardening
specs:
  - ../specs/interop-testing.md
---

Completed [May 31, 2026](../../CHANGELOG.md#2026-05-31).

## Verification

```bash
mix test
hurl --test --jobs 1 --variable base_url=http://localhost:4000 \
  test/smoke/tempest_basic.hurl test/smoke/tempest_compat.hurl
```

The smoke tests verify basic PDS flows, compatibility endpoints, `applyWrites`,
`getBlocks`, preference compatibility endpoints, `requestCrawl`, and unknown
AppView method fallback behavior.
