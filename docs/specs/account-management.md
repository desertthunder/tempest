---
title: Account Management Control Panel
updated: 2026-06-21
status: implemented
---

Reference documentation: ../reference/account-management.md

## HTTP verification

```bash
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  --variable suffix="$(date +%s)" \
  test/smoke/account-management.hurl

hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  --variable admin_did="$TEMPEST_ADMIN_DID" \
  --variable admin_identifier="$ADMIN_IDENTIFIER" \
  --variable admin_password="$ADMIN_PASSWORD" \
  test/smoke/account-management-admin.hurl
```
