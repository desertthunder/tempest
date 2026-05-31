---
title: Milestone 07 - Firehose
specs:
  - ../specs/sync-firehose.md
---

Completed [May 8, 2026](../../CHANGELOG.md#2026-05-08).

## Verification

```bash
hurl --test --jobs 1 --variable base_url=http://localhost:4000 test/smoke/firehose.hurl
```

The smoke test verifies subscription, a repository write, and receipt of a
commit event with increasing `seq`.
