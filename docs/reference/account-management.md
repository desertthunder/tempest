---
title: Account Management Control Panel
updated: 2026-06-21
---

Tempest has two browser control panels. The account panel is for a person inspecting
their own hosted account. The admin panel is for operating the Tempest instance.

## Authority

An account session can inspect one hosted account to view identity state,
repo state, blobs, access grants, security events, migration status, sequencer
events, and firehose activity for that account.

An admin session can inspect and operate the Tempest instance. It can show
service health, hosted accounts, storage state, repo operations, service
backups, compatibility status, and external account backup state.

Admins can see hosted-account metadata through admin pages but do not gain a
silent user session for that account.

## Browser Login

Account login uses Tempest's local account credentials, the same credentials
used for normal AT Protocol session creation.

This is configured with `TEMPEST_ADMIN_DID`. When that DID is hosted by
the local Tempest instance, the operator logs in with local account credentials.
Tempest then checks that the authenticated DID equals the configured admin DID.

This makes the admin identity follow the DID. It avoids tying admin access to a
particular PDS URL or to a long-lived token in the browser.

## Account Panel

The account panel is read-oriented. It reads from Tempest contexts directly
instead of calling Tempest's own XRPC routes as an internal API.

The panel can show that a credential or grant exists but does not show the
saved credential value.

## Admin Panel

The admin panel is the browser view of the same service operations exposed by
Mix tasks and admin status checks. It covers service status, hosted accounts,
storage, repo verification, repo import/export, service backup creation,
restore dry-run checks, compatibility status, and external account backups.

These mutations use CSRF-checked browser forms and confirmation screens where
the operation can remove data or change service state.

## External Account Backups

External account backups are admin-only snapshots of AT Protocol accounts
controlled by the operator. They are personal account backups, not whole-PDS
disaster recovery. They also do not migrate an external account into Tempest.

The source PDS is read-only from Tempest's point of view. Public repository and
blob backup can run without credentials. If the operator provides an app
password or access token, Tempest can also fetch private preferences through
`app.bsky.actor.getPreferences`.

Tempest resolves the source PDS from the account's DID document, using the
`#atproto_pds` service. Operators can pin a source PDS for an account, but the
pinned value must match the resolved identity. If the DID document points
somewhere else, backup fails instead of reading from the wrong server.

Credential state is recorded separately from the secret. Supported modes are no
credential, app password, and access token. Stored secrets are encrypted and are
not shown again after save. If preference auth fails, Tempest records the
warning without exposing the secret and can still keep the public repo/blob
snapshot.

## Snapshots

A completed snapshot is immutable. It should be understandable from the files in
the snapshot, even without Tempest database rows.

The main files are:

- `manifest.json`
- `repo.car`
- blob files named by CID
- `preferences.json` (if fetched)
- `verification-report.json`

The manifest records the account DID, handle, source PDS, commit CID, rev, repo
byte size, hashes, blob completeness, preference inclusion, and verification
status. That makes the snapshot portable across storage backend changes and
future database changes.

Exported bundles contain the same sensitive data as the snapshot. Treat them as
private backups.

## Verification

Snapshot verification checks whether the backup can prove what it claims.

For repository data, Tempest uses repo-core validation for the CAR root, commit
DID, commit signature, MST completeness, record paths, record CIDs, and CAR
integrity.

For blobs, Tempest checks stored bytes against the CID. For
preferences, Tempest records whether the preferences file was included and why
it may have been skipped.

Offline verification does not contact the source PDS. A backup should remain
useful if the source server is down or no longer hosts the account. Identity
freshness is a separate check; an old snapshot can still be valid after the
account migrates.

## Retention And Scheduling

Retention is per external account. Tempest supports keep all, keep last N, and
keep for days. Pinned snapshots are not pruned.

Manual backup is the primary operation. Scheduled backup exists for routine
checks and defaults to one account at a time. Blob downloads may run with bounded
concurrency, but snapshot state for a single account is serialized.

## Checks

Personal backup operations also have Mix tasks for backup creation, listing,
status, offline verification, export, pruning, and scheduled runs. If you're
self-hosting/operating a tempest instance, use the tasks when you need the
same behavior outside the browser.
