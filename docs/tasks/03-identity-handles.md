---
title: Milestone 03 - Identity and Handles
specs:
  - ../specs/identity-handles.md
---

Completed [May 7, 2026](../../CHANGELOG.md#2026-05-07).

## Verification

```bash
suffix="$(date +%s)"
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  --variable account_handle="identity-${suffix}.test" \
  --variable account_email="identity-${suffix}@example.com" \
  --variable account_password="correct horse battery staple" \
  test/smoke/identity.hurl
```

This milestone covers local identity and handle behavior. Network identity
correctness for hosted DIDs is tracked in Milestone 11.
