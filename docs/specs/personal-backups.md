---
title: Personal Account Backups
updated: 2026-06-13
status: planned
---

Tempest should be able to back up other AT Protocol accounts controlled by the
operator without becoming the active PDS for those accounts.

This feature is custody and archive work. It must not update identity, submit PLC
operations, activate accounts, write records to source PDS instances, or imply
that Tempest is hosting the backed-up account.

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

The repository spec defines full repo exports as CAR files suitable for sync,
offline backup, and migration. The sync spec exposes unauthenticated
`com.atproto.sync.getRepo` for public repository export. Blob backup should use
`com.atproto.sync.listBlobs` and `com.atproto.sync.getBlob`; both are PDS
endpoints and do not require auth for public blobs. Private preferences require
auth through `app.bsky.actor.getPreferences`.

The Tranquil local reference reinforces two design constraints. First, operator
guidance there treats repo CAR export, blob download, preference export, and
separately held rotation keys as distinct backup concerns. Second, Tranquil's
history includes an `account_backups` table with `storage_key`, repo root CID,
rev, block count, size, and created time, followed later by a migration that
dropped the table. Treat that as a warning to keep Tempest's first account
backup format portable and manifest-driven instead of tightly coupling it to
one internal storage engine.

## Goals

- Register external accounts by DID and handle.
- Back up public repository state as immutable CAR snapshots.
- Back up public blobs associated with the account.
- Back up private preferences when the operator supplies account credentials.
- Verify each snapshot before marking it complete.
- Export a portable bundle containing CAR, blobs, preferences, manifest, and
  verification report.
- Keep this feature separate from account migration and active hosting.

## Non-goals

- No PLC updates.
- No identity migration.
- No automatic activation of backed-up accounts on Tempest.
- No writes to the source PDS in the first version.
- No backups of DMs, notifications, AppView-only timelines, label-service state,
  moderation decisions stored outside the PDS, or feed-generator state.
- No broad network crawler. The operator must explicitly add each account.
- No whole-PDS disaster recovery in this feature. Tempest's service backup and
  restore work remains separate from per-account personal snapshots.

## Account Registry

Add a registry for external accounts. Each entry should include:

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

`source_pds_url` is the PDS used for backup reads. It can be discovered from the
DID document, but the operator may pin it for an account. If discovery and the
pinned source disagree, the backup should fail closed unless the operator
confirms a source update.

## Credentials

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

## Snapshot Model

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

## Backup Flow

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

## Verification

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

## Admin UI

Add an admin-only account backup area:

```text
/admin/backups/accounts
/admin/backups/accounts/:id
```

The UI should show:

- registered accounts;
- credential state, without secret values;
- latest snapshot status;
- backup now action;
- verification action;
- snapshot list;
- missing blob report;
- export bundle download or object-storage location;
- source PDS and identity mismatch warnings.

The operator account UI may link to this area, but external account backups are
admin-only in the first version.

## Scheduling

Manual backup comes first. Scheduled backup can follow after the manual flow is
stable.

Scheduling rules:

- Run one account backup at a time by default.
- Use `Task.async_stream/3` with bounded concurrency only for blob downloads.
- Persist backup run state so an interrupted run can be marked failed or resumed.
- Do not retry auth failures without operator action.
- Use exponential backoff for transient source PDS or object-storage errors.

## Storage and Retention

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

- admin auth for all personal backup routes and APIs;
- no public snapshot listing;
- no public bundle downloads;
- no credential values in logs or templates;
- redacted error messages for auth headers and tokens;
- rate limits on manual backup triggers;
- clear warning before deleting snapshots.

## HTTP Verification

Future smoke test:

```bash
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  --variable admin_token="$ADMIN_TOKEN" \
  test/smoke/personal-backups.hurl
```

The smoke test should cover account registration, public repo snapshot creation,
blob backup, credentialed preferences backup against a fixture server, snapshot
verification, export bundle creation, and deletion of an unpinned snapshot.
