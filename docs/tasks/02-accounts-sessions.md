---
title: Milestone 02 - Accounts and Sessions
specs:
  - ../specs/storage-sqlite.md
  - ../specs/accounts-auth.md
---

Completed [May 7, 2026](../../CHANGELOG.md#2026-05-07).

## Verification

```bash
suffix="$(date +%s)"
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  --variable account_handle="smoke-${suffix}.test" \
  --variable account_email="smoke-${suffix}@example.com" \
  --variable account_password="correct horse battery staple" \
  test/smoke/accounts.hurl
```
