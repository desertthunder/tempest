---
title: Milestone 18 - Account Management Control Panel
specs:
  - ../specs/account-management.md
  - ../specs/admin-operations.md
  - ../specs/storage-sqlite.md
  - ../specs/security-oauth.md
references:
  - ../reference/account-migration.md
  - ../reference/blobs.md
  - ../reference/repo-core.md
  - ../reference/admin-operations.md
---

Goal: turn the current account and admin development tools into a browser-usable
Control Panel with separate user account management and admin control views.
External personal backups become an admin-only account-management feature.

## Auth And Routing

- [ ] T18-01: Add a browser-friendly account login page at `/account/login`
      backed by the existing account credential/session flow.
- [ ] T18-02: Add account logout and an account browser-session plug that
      authorizes `/account/*` from a session family or server-side session
      reference without requiring manual bearer headers.
- [ ] T18-03: Preserve bearer-token access for existing account tool smoke tests
      while ensuring browser sessions never store or render access or refresh
      tokens.
- [ ] T18-04: Add `TEMPEST_ADMIN_DID` config and validation. Admin browser auth
      must be anchored to this DID rather than a hardcoded PDS URL.
- [ ] T18-05: Add an admin login page at `/admin/login` that resolves
      `TEMPEST_ADMIN_DID`, discovers the current auth method, and authenticates
      either through local account login or AT Protocol OAuth.
- [ ] T18-06: Store only a server-side admin auth reference in the browser
      session. Do not store raw admin tokens, OAuth access tokens, refresh
      tokens, DPoP keys, or authorization artifacts in the browser session.
- [ ] T18-07: Keep `TEMPEST_ADMIN_TOKEN_HASH` available only as a bootstrap or
      automation credential where still needed by JSON/status checks.
- [ ] T18-08: Add admin logout and an admin browser-session plug that accepts a
      valid admin session and, for automation-only paths, the configured admin
      bearer token.
- [ ] T18-09: Put user and admin LiveViews in separate authenticated
      `live_session` groups.
- [ ] T18-10: Replace the current controller-backed account/admin tooling in
      place. Do not preserve old `/account/*` or `/admin/*` controller routes as
      redirects.
- [ ] T18-11: Add tests proving account sessions cannot access `/admin/*` and
      admin sessions cannot act as account auth for account-only XRPC methods.

## User Account Management

- [ ] T18-12: Convert the existing `/account` dashboard into a LiveView Control
      Panel page with identity, repository, blob, access, security, migration,
      sequencer, and firehose navigation.
- [ ] T18-13: Convert `/account/repo` to LiveView using existing repo-storage
      context helpers for collections, recent records, latest commit, and CAR
      download links.
- [ ] T18-14: Convert `/account/blobs` to LiveView using existing blob context
      helpers for temp/public blob state and public download links.
- [ ] T18-15: Convert `/account/access` and `/account/security` to LiveView
      inventory pages that never render token, app-password, OAuth, backup-code,
      or recovery secrets.
- [ ] T18-16: Convert `/account/migration`, `/account/sequencer`, and
      `/account/firehose` to LiveView pages with scoped account data.
- [ ] T18-17: Add account-management ConnCase or LiveView tests for login,
      logout, route auth, key element IDs, and redacted secret output.

## Admin Control Panel

- [ ] T18-18: Convert the existing `/admin` dashboard into a LiveView Control
      Panel page for service status, hosted accounts, sequencer status, storage,
      and compatibility warnings.
- [ ] T18-19: Add `/admin/accounts` and `/admin/accounts/:did` for hosted
      account inspection, using admin auth only.
- [ ] T18-20: Convert `/admin/storage`, `/admin/repo`, `/admin/backups`, and
      `/admin/compatibility` to LiveView or keep thin controller actions where
      file downloads/forms make that simpler.
- [ ] T18-21: Keep admin operations backed by context modules rather than
      calling Tempest's own XRPC HTTP endpoints internally.
- [ ] T18-22: Add confirmations and CSRF-protected forms for admin mutations
      such as repo import, backup create, restore dry-run, prune, and delete.
- [ ] T18-23: Add admin tests for local-admin login, external-admin OAuth login
      with a fixture auth server, bearer-token automation access, account-token
      rejection, route rendering, and mutation confirmation flows.

## External Account Backups

- [ ] T18-24: Add a `Tempest.PersonalBackups` context and migrations for
      external backup accounts, backup runs, immutable snapshots, blob records,
      credentials, and retention settings.
- [ ] T18-25: Add external account registration with DID, handle, optional
      pinned source PDS URL, label, credential state, and status fields. The
      default source PDS must be resolved from the DID document, not hardcoded.
- [ ] T18-26: Add identity/source verification that resolves handle and DID
      document, verifies `#atproto_pds`, and fails closed on mismatched pinned
      source PDS values.
- [ ] T18-27: Add credential storage for no-auth, app-password, and access-token
      modes. Store secrets defensively, never render them, and allow rotation and
      deletion.
- [ ] T18-28: Add a source PDS client using `Req` for
      `com.atproto.sync.getRepo`, `com.atproto.sync.listBlobs`,
      `com.atproto.sync.getBlob`, and `app.bsky.actor.getPreferences`.
- [ ] T18-29: Add CAR snapshot creation that stores `repo.car`, commit CID, rev,
      byte size, hash, source PDS, handle, and DID.
- [ ] T18-30: Reuse repo-core verification to validate commit DID, commit
      signature, MST completeness, record paths, record CIDs, and CAR integrity.
- [ ] T18-31: Extract blob references from repo records and merge them with
      paginated `listBlobs` output.
- [ ] T18-32: Add bounded concurrent blob download with CID verification,
      missing-blob recording, and retry handling for transient source failures.
- [ ] T18-33: Add credentialed private preference backup through
      `app.bsky.actor.getPreferences`, with auth failures reported separately
      from public repo/blob backup status.
- [ ] T18-34: Write immutable snapshot manifests and verification reports, first
      to a temporary workspace and then atomically mark snapshots complete.
- [ ] T18-35: Store personal backup snapshots through the existing local and
      S3/R2 backup storage shape.
- [ ] T18-36: Add retention policies: keep all, keep last N, keep for days, and
      pinned snapshots.
- [ ] T18-37: Add portable export bundle creation containing manifest, repo CAR,
      blobs, preferences JSON when present, and verification report.
- [ ] T18-38: Add offline snapshot verification that can run without contacting
      the source PDS.
- [ ] T18-39: Add tests proving a snapshot can be understood from its manifest
      and files without relying on Tempest database rows.
- [ ] T18-40: Add Mix tasks for backup, verify, list snapshots, export bundle,
      prune, and show account backup status.
- [ ] T18-41: Add admin-only LiveView routes for external backup account list,
      detail, create, edit, delete, backup now, verify, prune, and export.
- [ ] T18-42: Add admin UI for credential state, latest backup status, missing
      blobs, snapshot history, storage totals, and source identity warnings.
- [ ] T18-43: Add manual backup locking so two runs cannot mutate the same
      account snapshot workspace at the same time.
- [ ] T18-44: Add optional scheduled backups after manual backups are stable,
      with one-account-at-a-time default scheduling and persisted run state.

## Tests And Docs

- [ ] T18-45: Add unit tests for account registration, credential redaction,
      manifest writing, retention pruning, and snapshot state transitions.
- [ ] T18-46: Add fixture-server integration tests for `getRepo`, `listBlobs`,
      `getBlob`, preferences auth success, preferences auth failure, missing
      blobs, bad CIDs, bad CARs, and source identity mismatch.
- [ ] T18-47: Add admin LiveView tests for route auth, create/edit forms,
      backup-now action, verification action, export action, and deletion
      confirmation.
- [ ] T18-48: Add Hurl smoke test `test/smoke/account-management.hurl` for user
      login and user Control Panel access.
- [ ] T18-49: Add Hurl smoke test `test/smoke/account-management-admin.hurl` for
      admin login, admin route auth, and external backup flows.
- [ ] T18-50: Add reference documentation after implementation describing the
      account-management routes, login model, backup format, export limits,
      security model, and operational checks.

## Integration Tests

- User login creates an account browser session containing only a session family
  or server-side session reference.
- User logout clears account browser-session access.
- Admin login resolves `TEMPEST_ADMIN_DID` and succeeds through local account
  auth or AT Protocol OAuth, depending on where the DID is hosted.
- Admin login creates an admin browser session containing only a server-side
  admin auth reference.
- Admin logout clears admin browser-session access.
- Account sessions cannot access admin pages.
- Admin sessions cannot act as account XRPC auth.
- Account and admin browser sessions never store raw access tokens, refresh
  tokens, OAuth artifacts, DPoP keys, or raw admin tokens.
- PDS URLs are resolved from DIDs and service metadata unless an operator
  explicitly pins a source PDS for an external backup account.
- Public repo backup succeeds without credentials.
- Blob backup stores every available listed or referenced blob.
- CID mismatch marks a snapshot failed.
- Missing blobs are recorded and visible to the operator.
- Private preferences are included only when valid credentials are configured.
- Auth failures do not leak secrets and do not destroy public backup output.
- Offline verification catches corrupted CAR, blob, manifest, and preferences
  files.
- Retention pruning never deletes pinned snapshots.
- Admin routes reject unauthenticated, account-token, and normal app-password
  requests.

## HTTP Verification

```bash
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  --variable suffix="$(date +%s)" \
  test/smoke/account-management.hurl

hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  --variable admin_did="$TEMPEST_ADMIN_DID" \
  --variable admin_login_mode=fixture_oauth \
  test/smoke/account-management-admin.hurl
```

## Implementation Notes

Keep LiveViews thin. Account and admin pages should call Tempest context modules
directly rather than calling Tempest's own XRPC HTTP routes internally.

Use XRPC for protocol-compatible client endpoints and outbound reads from source
PDS instances. Use `Req` for outbound HTTP.

Keep external account backups read-only against source PDS instances in the
first version. The backup client may authenticate to read private preferences,
but it must not write records, submit PLC operations, activate accounts,
deactivate accounts, or call migration endpoints.

Prefer portable snapshot bundles over direct restore. Direct restore into
Tempest belongs in migration work after backup verification has real use.
