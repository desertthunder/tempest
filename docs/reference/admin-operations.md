---
title: Admin and Operator Operations
updated: 2026-06-03
---

Tempest has two operator surfaces:

- account tools under `/account/*`, authenticated with a normal account bearer
  token
- admin tools under `/admin/*` and `/xrpc/_admin/status`, authenticated with the
  configured admin bearer token

Normal account tokens must not authenticate admin routes. Admin tokens are stored
as hashes through `TEMPEST_ADMIN_TOKEN_HASH` and verified by `Tempest.AdminAuth`.

## Account operator UI

The account UI is for inspecting the signed-in account while developing or
operating a single-user PDS. It uses the same XRPC bearer token clients use.

Routes:

- `/account`: identity and repository summary
- `/account/repo`: collections, recent records, latest commit, and CAR link
- `/account/blobs`: temp/public blob state, download links, and header summary
- `/account/access`: sessions, OAuth grants, app passwords, delegated access
- `/account/security`: email, password, MFA, backup codes, trusted devices, events
- `/account/migration`: activation and migration-readiness status
- `/account/sequencer`: recent sequencer events with DID/type filters
- `/account/firehose`: recent decoded `subscribeRepos` frames and WebSocket URL

The UI is intentionally read-mostly except for the protocol endpoints it links to.
Secrets such as app-password values, refresh tokens, OAuth token hashes, backup
code hashes, and admin tokens are never displayed.

## Admin UI

Admin routes require `Authorization: Bearer $ADMIN_TOKEN`.

Routes:

- `/admin`: service, account, sequencer, storage, and relay crawl status
- `/admin/invites`: invite-code profile status for this deployment
- `/admin/repo`: repo verify/export/import actions
- `/admin/backups`: backup create and restore dry-run
- `/admin/storage`: local database directories, blob store, and backup store
- `/admin/compatibility`: endpoint compatibility matrix

The JSON status endpoint remains:

```text
GET /xrpc/_admin/status
```

It reports database files, sequencer position, blob-store status, admin auth
configuration, and per-account repo/blob counts.

## Mix tasks

Development and release operations are exposed first as Mix tasks:

```bash
mix pds.repo.verify --did DID
mix pds.repo.export --did DID --output /path/to/repo.car
mix pds.repo.import --did DID --input /path/to/repo.car
mix pds.sequencer.status
mix pds.blob.gc
mix pds.backup.create [--output /path/to/backup-dir] [--upload-s3]
mix pds.backup.restore --input /path/to/backup-dir --target /path/to/data
```

The UI calls the same context helpers used by these tasks where possible, keeping
controllers thin and reducing behavior drift.

## Backups

`Tempest.Admin.Backup.create/1` checkpoints SQLite WAL files, copies durable data,
writes a manifest, and can upload a backup archive through the S3-compatible
backup adapter.

Restore refuses to overwrite a live data directory unless the caller opts into a
forced restore. The admin UI exposes a dry run only: it checks manifest presence
and whether the target contains live database files, then reports what would
happen without copying data.

## Verification

```bash
mix test test/tempest_web/controllers/admin_controller_test.exs \
  test/tempest_web/controllers/operator_account_controller_test.exs

hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  --variable suffix="$(date +%s)" \
  test/smoke/operator-account-ux.hurl
```

The ConnCase tests cover account/admin auth boundaries and route rendering. The
smoke test covers account UI access through a running server.
