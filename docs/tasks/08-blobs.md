---
title: Milestone 08 - Blobs
specs:
  - ../specs/blobs.md
---

Completed [May 8, 2026](../../CHANGELOG.md#2026-05-08).

## Verification

```bash
hurl --test --jobs 1 --variable base_url=http://localhost:4000 test/smoke/blobs.hurl
```

The smoke test verifies upload, temporary/private state, record reference,
listing, serving, and blob response headers.
