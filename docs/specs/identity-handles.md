---
title: Identity and Handles
updated: 2026-06-13
status: implemented
---

Reference documentation: ../reference/identity-handles.md

Verification:

```bash
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  --variable account_handle="identity-${suffix}.test" \
  --variable account_email="identity-${suffix}@example.com" \
  --variable account_password="correct horse battery staple" \
  test/smoke/identity.hurl

hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  test/smoke/identity-correctness.hurl
```
