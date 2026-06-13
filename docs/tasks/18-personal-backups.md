---
title: Milestone 18 - Personal Account Backups
specs:
  - ../specs/personal-backups.md
  - ../specs/admin-operations.md
  - ../specs/storage-sqlite.md
  - ../specs/security-oauth.md
references:
  - ../reference/account-migration.md
  - ../reference/blobs.md
  - ../reference/repo-core.md
  - ../reference/admin-operations.md
---

Goal: let the operator back up other AT Protocol accounts they control, without
turning Tempest into the active PDS for those accounts.

- [ ] T18-01: Add a `Tempest.PersonalBackups` context and migrations for
      external backup accounts, backup runs, immutable snapshots, blob records,
      and retention settings.
- [ ] T18-02: Add account registration with DID, handle, source PDS URL, label,
      and status fields.
- [ ] T18-03: Add identity/source verification that resolves handle and DID
      document, verifies `#atproto_pds`, and fails closed on mismatched pinned
      source PDS values.
- [ ] T18-04: Add credential storage for no-auth, app-password, and access-token
      modes. Store secrets defensively, never render them, and allow rotation and
      deletion.
- [ ] T18-05: Add a source PDS client using `Req` for `com.atproto.sync.getRepo`,
      `com.atproto.sync.listBlobs`, `com.atproto.sync.getBlob`, and
      `app.bsky.actor.getPreferences`.
- [ ] T18-06: Add CAR snapshot creation that stores `repo.car`, commit CID, rev,
      byte size, hash, source PDS, handle, and DID.
- [ ] T18-07: Reuse repo-core verification to validate commit DID, commit
      signature, MST completeness, record paths, record CIDs, and CAR integrity.
- [ ] T18-08: Extract blob references from repo records and merge them with
      paginated `listBlobs` output.
- [ ] T18-09: Add bounded concurrent blob download with CID verification,
      missing-blob recording, and retry handling for transient source failures.
- [ ] T18-10: Add credentialed private preference backup through
      `app.bsky.actor.getPreferences`, with auth failures reported separately
      from public repo/blob backup status.
- [ ] T18-11: Write immutable snapshot manifests and verification reports, first
      to a temporary workspace and then atomically mark snapshots complete.
- [ ] T18-12: Store personal backup snapshots through the existing local and
      S3/R2 backup storage shape.
- [ ] T18-13: Add retention policies: keep all, keep last N, keep for days, and
      pinned snapshots.
- [ ] T18-14: Add portable export bundle creation containing manifest, repo CAR, blobs,
      preferences JSON when present, and verification report.
- [ ] T18-15: Add offline snapshot verification that can run without contacting
      the source PDS.
- [ ] T18-16: Add tests proving a snapshot can be understood from its manifest
      and files without relying on Tempest database rows.
- [ ] T18-17: Add Mix tasks for backup, verify, list snapshots, export bundle,
      prune, and show account backup status.
- [ ] T18-18: Add admin-only routes and controllers for external backup account
      list, detail, create, edit, delete, backup now, verify, prune, and export.
- [ ] T18-19: Add admin templates under the existing UI language for credential
      state, latest backup status, missing blobs, snapshot history, storage
      totals, and source identity warnings.
- [ ] T18-20: Add manual backup locking so two runs cannot mutate the same
      account snapshot workspace at the same time.
- [ ] T18-21: Add optional scheduled backups after manual backups are stable,
      with one-account-at-a-time default scheduling and persisted run state.
- [ ] T18-22: Add unit tests for account registration, credential redaction,
      manifest writing, retention pruning, and snapshot state transitions.
- [ ] T18-23: Add fixture-server integration tests for `getRepo`, `listBlobs`,
      `getBlob`, preferences auth success, preferences auth failure, missing
      blobs, bad CIDs, bad CARs, and source identity mismatch.
- [ ] T18-24: Add admin ConnCase tests for route auth, create/edit forms,
      backup-now action, verification action, export action, and deletion
      confirmation.
- [ ] T18-25: Add Hurl smoke test `test/smoke/personal-backups.hurl`.
- [ ] T18-26: Add reference documentation after implementation describing the
      backup format, restore/export limits, security model, and operational
      checks.

## Integration Tests

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
  --variable admin_token="$ADMIN_TOKEN" \
  test/smoke/personal-backups.hurl
```

## Implementation Notes

Keep this feature read-only against source PDS instances in the first version.
The backup client may authenticate to read private preferences, but it must not
write records, submit PLC operations, activate accounts, deactivate accounts, or
call migration endpoints.

Prefer portable snapshot bundles over direct restore. Direct restore into Tempest
belongs in migration work after backup verification has real use.
