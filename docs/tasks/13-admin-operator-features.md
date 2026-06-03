---
title: Milestone 13 - Admin, Storage, and Operator Features
specs:
  - ../specs/admin-operations.md
  - ../specs/deployment-observability.md
  - ../specs/security-oauth.md
  - ../specs/pds-compatibility.md
---

Goal: finish the local feature work needed to operate Tempest before deployment
or network compatibility testing.

This slice exists to increase development observability:

- [x] T13-01: Add minimal authenticated account dashboard.
- [x] T13-02: Add repo browser for the authenticated account.
- [x] T13-03: Add blob browser (temp/public state + download links + headers summary).
- [x] T13-04: Add sequencer viewer (tail `repo_seq` + filters by DID/type).
- [x] T13-05: Add firehose viewer (subscribe + decode frames for display).

---

- [x] T13-06: Add admin token hashing and verification.
- [x] T13-07: Add admin status endpoint.
- [x] T13-08: Add `mix pds.repo.verify`.
- [x] T13-09: Add `mix pds.repo.export`.
- [x] T13-10: Add `mix pds.repo.import`.
- [x] T13-11: Add `mix pds.sequencer.status`.
- [x] T13-12: Add `mix pds.blob.gc`.
- [x] T13-13: Add `mix pds.backup.create` and `mix pds.backup.restore`.
- [x] T13-14: Add S3-compatible blob adapter.
- [x] T13-15: Add S3-compatible SQLite backup upload for SQLite deployments.
- [x] T13-16: Add SMTP adapter and account security notifications.
- [x] T13-17: Add telemetry events for XRPC, repo writes, blobs, and firehose.
- [ ] T13-18: Add UI for sessions, OAuth grants, app passwords, and delegated access.
- [ ] T13-19: Add UI for email, password, MFA, backup codes, and trusted devices.
- [ ] T13-20: Add admin dashboard for account status, sequencer, storage, and relay crawl status.
- [ ] T13-21: Add invite-code management UI.
- [ ] T13-22: Add repo verify/export/import actions in operator UI.
- [ ] T13-23: Add backup create/restore dry-run UI.
- [ ] T13-24: Add storage status UI for local blobs, S3/R2 blobs, and backups.
- [ ] T13-25: Add account migration in/out status UI.
- [ ] T13-26: Add compatibility status view based on the reference endpoint matrix.

## Integration Tests

- Account UI cannot be reached without an account session.
- Admin UI cannot be reached with normal account credentials.
- Admin status requires admin token and reports DB, sequencer, repo, and blob
  status.
- Repo verify catches corrupted or missing blocks.
- Backup dry run refuses to overwrite live data.
- S3/R2 adapters can be tested with a local S3-compatible service or mocked
  client.
- Compatibility status reflects implemented and tested behavior, not only routes.

## HTTP Verification

```bash
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  --variable suffix="$(date +%s)" \
  --variable admin_token="$ADMIN_TOKEN" \
  test/smoke/operator-account-ux.hurl
```
