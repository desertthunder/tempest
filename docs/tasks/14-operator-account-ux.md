---
title: Milestone 14 - Operator and Account Management UX
specs:
  - ../specs/admin-operations.md
  - ../specs/deployment-observability.md
  - ../specs/security-oauth.md
---

Goal: give self-hosters enough UI and operational tooling to run the PDS safely.

## Tasks

- [ ] T14-01: Add minimal authenticated account dashboard.
- [ ] T14-02: Add UI for sessions, OAuth grants, app passwords, and delegated access.
- [ ] T14-03: Add UI for email, password, MFA, backup codes, and trusted devices.
- [ ] T14-04: Add repo browser for the authenticated account.
- [ ] T14-05: Add admin dashboard for account status, sequencer, storage, and relay crawl status.
- [ ] T14-06: Add invite-code management UI.
- [ ] T14-07: Add one-click repo verify from admin UI.
- [ ] T14-08: Add backup create/restore dry-run commands.
- [ ] T14-09: Add S3-compatible blob adapter.
- [ ] T14-10: Add S3-compatible SQLite backup upload for SQLite deployments.
- [ ] T14-11: Add SMTP adapter and account security notifications.
- [ ] T14-12: Add deployment docs for local-only, S3-backed, and reverse-proxy setups.
- [ ] T14-13: Add restore-drill test that verifies DBs, repos, blobs, signing keys, and OAuth keys together.

## Integration Tests

- Account UI cannot be reached without an account session.
- Admin UI cannot be reached with normal account credentials.
- Backup dry run refuses to overwrite live data.
- Restore drill produces a server that passes read-only smoke tests.

## HTTP Verification

```bash
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  --variable admin_token="$ADMIN_TOKEN" \
  test/smoke/operator-account-ux.hurl
```
