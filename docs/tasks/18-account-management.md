---
title: Milestone 18 - Account Management Control Panel
specs:
  - ../specs/account-management.md
  - ../specs/admin-operations.md
  - ../specs/storage-sqlite.md
  - ../specs/security-oauth.md
references:
  - ../reference/account-management.md
  - ../reference/account-migration.md
  - ../reference/blobs.md
  - ../reference/repo-core.md
  - ../reference/admin-operations.md
---

Completed [June 21, 2026](../../CHANGELOG.md#2026-06-21).

## Verification

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

The account-management control panel adds browser account login, browser admin
login anchored to `TEMPEST_ADMIN_DID`, separate account/admin LiveView sessions,
admin-only external account backups, portable snapshot exports, offline
verification, retention controls, and redaction tests for token and credential
material.

Reference documentation: [Account Management Control Panel](../reference/account-management.md).
