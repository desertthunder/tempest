---
title: Account Management Control Panel
updated: 2026-06-14
status: planned
---

Tempest should expose account management as a Control Panel with two separate
views:

- user account management for the signed-in hosted account;
- admin controls for the operator who manages the Tempest instance.

These views share visual language and some underlying context modules, but they
must not share authority. A normal account token must never authorize admin
actions. An admin token must never silently act as a hosted account.

## Source Baseline

Research checked on 2026-06-13:

- AT Protocol Repository spec: <https://atproto.com/specs/repository>
- AT Protocol Sync spec: <https://atproto.com/specs/sync>
- AT Protocol Blob Lifecycle guide: <https://atproto.com/guides/blob-lifecycle>
- AT Protocol Account Migration guide:
  <https://atproto.com/guides/account-migration>
- `com.atproto.sync.listBlobs` Lexicon:
  <https://github.com/bluesky-social/atproto/blob/main/lexicons/com/atproto/sync/listBlobs.json>
- `com.atproto.sync.getBlob` Lexicon:
  <https://github.com/bluesky-social/atproto/blob/main/lexicons/com/atproto/sync/getBlob.json>
- `app.bsky.actor.getPreferences` Lexicon:
  <https://github.com/bluesky-social/atproto/blob/main/lexicons/app/bsky/actor/getPreferences.json>
- Official Bluesky PDS distribution:
  <https://github.com/bluesky-social/pds>
- Reference PDS implementation:
  <https://github.com/bluesky-social/atproto/tree/main/packages/pds>
- Cocoon PDS:
  <https://github.com/haileyok/cocoon>
- Tranquil PDS local reference:
  <https://tangled.org/tranquil.farm/tranquil-pds>

## Goals

- Provide a browser-friendly account management UI instead of requiring manual
  bearer headers for every page.
- Keep user account management and admin controls as separate authenticated
  surfaces.
- Let a hosted user inspect their account, repo, blobs, sessions, app passwords,
  OAuth grants, security events, migration state, sequencer events, and firehose
  state.
- Let an admin inspect service health, storage, hosted accounts, compatibility,
  repo operations, service backups, and external account backups.
- Add personal account backups as an admin-only account-management feature for
  external AT Protocol accounts controlled by the operator.
- Use LiveView for Control Panel workflows and shared context modules for
  behavior.
- Use XRPC as the protocol boundary for clients and external PDS calls, not as
  the primary internal API between LiveViews and Tempest contexts.
- Resolve PDS locations from DIDs and service metadata instead of hardcoding
  PDS URLs in account-management config.

## Non-goals

- No hosted-provider moderation console in this milestone.
- No admin impersonation of a user account.
- No automatic account migration from external backup snapshots.
- No PLC updates from the personal-backup flow.
- No writes to source PDS instances during personal backup.
- No backups of DMs, notifications, AppView-only timelines, label-service state,
  moderation decisions stored outside the PDS, or feed-generator state.
- No whole-PDS disaster recovery inside personal account backups. Service backup
  and restore remain separate admin operations.

## Route Model

User account management should live under `/account/*`:

```text
/account/login
/account/logout
/account
/account/repo
/account/blobs
/account/access
/account/security
/account/migration
/account/sequencer
/account/firehose
```

Admin controls should live under `/admin/*`:

```text
/admin/login
/admin/logout
/admin
/admin/accounts
/admin/accounts/:did
/admin/storage
/admin/repo
/admin/sequencer
/admin/security
/admin/backups
/admin/backups/service
/admin/backups/accounts
/admin/backups/accounts/:id
/admin/compatibility
```

The implementation should replace the current controller-backed account/admin
tooling in place. Do not preserve old `/account/*` or `/admin/*` controller
routes as redirects.

## Login And Auth

### User Login

The user login flow should authenticate a hosted account through the existing
account credential model:

```text
POST /xrpc/com.atproto.server.createSession
```

The browser form should accept identifier, password, and any required
second-factor token for locally hosted accounts. On success, Tempest should
store only a session family or server-side session reference in the browser
session. It must not store raw access tokens or refresh tokens in the browser
session, and it must not render access tokens, refresh tokens, app-password
values, OAuth token hashes, backup-code hashes, or recovery secrets.

The user session authorizes only `/account/*` pages and user-scoped operations.
It does not authorize `/admin/*`.

The existing bearer-token behavior can remain for development and smoke tests,
but browser users should not need to manually attach `Authorization` headers.

### Admin Login

The admin identity should be configured by DID, not by a hardcoded PDS URL:

```text
TEMPEST_ADMIN_DID=did:plc:...
```

`/admin/login` should resolve `TEMPEST_ADMIN_DID`, discover the account's current
PDS/auth metadata, and choose the correct authentication method.

If the admin DID is hosted by this Tempest instance, the login can use the local
account credential/session flow and then verify that the authenticated account
DID equals `TEMPEST_ADMIN_DID`.

If the admin DID is hosted elsewhere, including a Bluesky PDS, the login should
use AT Protocol OAuth for that DID. The browser session should store only a
server-side admin auth reference, not OAuth access tokens, refresh tokens, DPoP
keys, or raw authorization artifacts.

`TEMPEST_ADMIN_TOKEN_HASH` may remain as a bootstrap or automation credential
for existing JSON/status checks, but it should not be the primary browser
Control Panel login model.

Admin sessions authorize only `/admin/*` pages and admin operations. They do not
act as a hosted account and must not be accepted by account-only XRPC methods.

### Shared Safeguards

- Put user and admin LiveViews in separate authenticated `live_session` groups.
- Keep separate plugs for account-session auth and admin-session auth.
- Apply CSRF protection to browser forms.
- Rate-limit login attempts and manual backup triggers.
- Redact auth headers, credentials, and tokens from logs and templates.
- Require explicit confirmations for destructive admin actions.
- Store only opaque session family IDs or server-side auth references in browser
  sessions.

## LiveView And XRPC Boundary

Control Panel pages should be LiveView-first:

```text
LiveView
  -> Tempest context module
    -> storage, repo, security, backup, or external-PDS client
```

LiveViews should not call Tempest's own XRPC HTTP endpoints for internal admin
work. They should call context modules directly so auth, validation, error
handling, and tests stay simple.

Use XRPC for:

- protocol-compatible endpoints used by external clients;
- links that intentionally download protocol resources, such as repo CARs or
  blobs;
- outbound calls to external PDS instances during personal backup.

Use `Req` for outbound HTTP.

## User Account Management View

The user view is scoped to the signed-in hosted account.

It should include:

- identity summary: DID, handle, email, active state, and hosting status;
- repository summary: collections, recent records, latest commit, and CAR link;
- blob browser: temp/public blob state, download links, and header summary;
- access inventory: sessions, OAuth grants, app passwords, delegated access;
- security inventory: email state, password state, MFA, backup codes, trusted
  devices, and security events;
- migration state: activation and migration-readiness status;
- sequencer view: recent events for the account;
- firehose view: recent decoded `subscribeRepos` frames and WebSocket URL.

The first version can stay mostly read-only. Mutating user actions should be
added only where there is already a safe context API and test coverage.

## Admin Control View

The admin view is scoped to the Tempest instance.

It should include:

- service status, version, public URL, configured host, and admin auth state;
- hosted account list and per-account detail;
- storage status for SQLite, repos, blobs, backups, and object storage;
- repo operations: verify, export, and import;
- sequencer status and recent events;
- security overview, including admin-token configuration and redacted security
  event summaries;
- service backup create and restore dry-run;
- compatibility matrix;
- external account backups.

Admin pages may show aggregate hosted-account information and operational
warnings. They must avoid exposing raw credentials or token material.

## External Account Backups

External account backups are part of admin account management because they may
contain private preferences and deleted public data. They must not be exposed in
the user account view except as a link or status note when appropriate.

This feature backs up other AT Protocol accounts controlled by the operator
without becoming the active PDS for those accounts.

### Account Registry

Add a registry for external accounts:

```text
id
label
did
handle
source_pds_url
credential_state
last_checked_at
last_success_at
last_snapshot_id
status
status_reason
inserted_at
updated_at
```

`did` is the stable account identifier. `handle` is display and discovery
metadata. A backup must verify that the resolved handle still points to the DID,
but a handle change must not orphan existing snapshots.

`source_pds_url` is the PDS used for backup reads. It must be resolved from the
DID document by default, not hardcoded. The operator may pin it for an account as
an explicit override. If discovery and the pinned source disagree, the backup
should fail closed unless the operator confirms a source update.

### Credentials

Support three credential states:

```text
none
app_password
access_token
```

Public repo and blob backup should work with no credential. Private preference
backup requires auth.

Credential rules:

- Store secrets encrypted or through the existing secret-storage approach chosen
  for deployment.
- Never display a stored secret after save.
- Allow credential replacement and deletion.
- Record credential kind and last verification time.
- Treat failed auth as a backup warning when public backup succeeds, not as a
  failed public backup.

### Snapshot Model

Each backup run creates a snapshot. A snapshot is immutable after completion.

Suggested manifest fields:

```json
{
  "version": 1,
  "account": { "did": "did:plc:...", "handle": "example.com", "sourcePds": "https://bsky.social" },
  "repo": { "carPath": "repo.car", "commit": "bafy...", "rev": "3l...", "byteSize": 12345, "sha256": "..." },
  "blobs": { "count": 10, "complete": true, "missing": [] },
  "preferences": { "included": true, "path": "preferences.json" },
  "verification": { "status": "ok", "checkedAt": "2026-06-13T00:00:00Z" }
}
```

Store snapshots under the existing backup storage profile. Local and S3/R2
storage should share the same logical layout:

```text
personal-backups/
  <did>/
    snapshots/
      <timestamp>-<rev>/
        manifest.json
        repo.car
        blobs/
          <cid>
        preferences.json
        verification.json
```

### Backup Flow

1. Resolve account identity.
2. Determine the source PDS from the DID document or pinned account config.
3. Fetch `com.atproto.sync.getRepo?did=<did>` from the source PDS.
4. Parse and verify the CAR.
5. Extract current commit CID, DID, rev, records, and blob references.
6. Call `com.atproto.sync.listBlobs` with pagination.
7. Fetch each blob with `com.atproto.sync.getBlob`.
8. Verify blob bytes match the expected CID.
9. If credentials are configured, call `app.bsky.actor.getPreferences`.
10. Write the snapshot to a temporary location.
11. Write manifest and verification report.
12. Atomically mark the snapshot complete.

If blob enumeration fails but repo backup succeeds, keep the snapshot incomplete
and record missing blob state. Do not mark the snapshot complete until every
referenced available blob is either stored or explicitly recorded as missing.

### Verification

A completed snapshot must prove:

- the CAR root points at a commit object;
- the commit DID matches the registered account DID;
- the commit signature verifies against the resolved DID document;
- the repo MST is complete for the exported commit;
- record paths and CIDs pass existing repo-core validation;
- blob CIDs discovered from records and `listBlobs` have matching stored bytes;
- preference JSON was fetched with auth when credentials were enabled;
- the manifest hashes match files on disk or in object storage.

Verification should be callable without contacting the source PDS, except for an
optional identity freshness check. Offline verification is the point of a backup.

### Scheduling

Manual backup comes first. Scheduled backup can follow after the manual flow is
stable.

Scheduling rules:

- Run one account backup at a time by default.
- Use `Task.async_stream/3` with bounded concurrency only for blob downloads.
- Persist backup run state so an interrupted run can be marked failed or resumed.
- Do not retry auth failures without operator action.
- Use exponential backoff for transient source PDS or object-storage errors.

### Storage And Retention

Retention should be explicit per account:

```text
keep_all
keep_last_n
keep_for_days
```

Default to `keep_last_n=3` for scheduled backups. Manual snapshots may be pinned
to prevent deletion.

Storage reporting should include:

- repo CAR bytes;
- blob bytes;
- preference bytes;
- manifest and verification bytes;
- total per account;
- total across personal backups.

The snapshot manifest should stay useful if Tempest later changes database or
object-storage internals. Do not make an internal row ID or storage backend the
only way to understand a backup.

## Security

Backups may contain private preference data and deleted public data that still
exists in an older snapshot. Treat bundles as sensitive.

Required safeguards:

- account auth for all user account-management routes;
- admin auth for all admin routes and personal-backup routes;
- no public snapshot listing;
- no public bundle downloads;
- no credential values in logs or templates;
- redacted error messages for auth headers and tokens;
- rate limits on login and manual backup triggers;
- clear warning before deleting snapshots.

## HTTP Verification

Future smoke tests:

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

The user smoke test should cover account login, user account dashboard access,
and rejection from admin routes. The admin smoke test should cover admin login,
hosted-account inspection, external account registration, public repo snapshot
creation, blob backup, credentialed preferences backup against a fixture server,
snapshot verification, export bundle creation, and deletion of an unpinned
snapshot.
