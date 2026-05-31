---
title: Milestone 06 - CAR and Sync Reads
specs:
  - ../specs/repo-core.md
  - ../specs/sync-firehose.md
---

Completed [May 8, 2026](../../CHANGELOG.md#2026-05-08).

## Verification

```bash
hurl --test --jobs 1 --variable base_url=http://localhost:4000 test/smoke/car-sync.hurl
```
