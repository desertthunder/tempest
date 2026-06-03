---
title: Admin Operations
updated: 2026-06-02
---

# Admin Operations

Self-hosted PDS users need repair, backup, restore, and inspection tools. Start with Mix tasks, then package a release CLI when deployment work begins.

## Commands

Development form:

```text
mix pds.account.list
mix pds.account.create
mix pds.account.suspend
mix pds.account.reset_password
mix pds.repo.verify
mix pds.repo.export
mix pds.repo.import
mix pds.sequencer.status
mix pds.sequencer.replay
mix pds.blob.gc
mix pds.backup.create
mix pds.backup.restore
```

Release form:

```text
tempest account list
tempest repo verify <did>
tempest backup create
```

## Admin API

Admin HTTP endpoints are optional. If added, they must be behind explicit admin auth and must not share normal account bearer tokens.

Minimum admin-visible HTTP checks:

```text
/xrpc/_health
/xrpc/_admin/status
```

## Backups

SQLite-first local backup:

1. Enter maintenance mode or pause writes.
2. Checkpoint WAL files.
3. Copy `account.sqlite`, `sequencer.sqlite`, `repos/`, `blobs/`, and keys.
4. Resume writes.
5. Run verification against the backup.

S3/R2-backed backup:

1. Enter maintenance mode or pause writes.
2. Checkpoint WAL files.
3. Copy SQLite DBs, WAL files, repos, and keys from the durable volume.
4. Verify blob references against the configured object store.
5. Upload the backup archive to the configured backup bucket.
6. Restore into a fresh directory or volume and run read-only smoke tests.

Online backup can use SQLite backup APIs later.

## Adversarial Checks

- Backup restore must not overwrite live data without explicit confirmation.
- Sequencer repair must not reuse a previous sequence number.
- Repo import must verify DID and commit signatures before activation.
- Admin commands must redact secrets in logs.

## HTTP Verification

```bash
http GET :4000/xrpc/_health
http GET :4000/xrpc/_admin/status "Authorization:Bearer $ADMIN_TOKEN"
```

Expected:

- Health is public and minimal.
- Admin status requires admin auth and returns database, sequencer, and blob-store status.

## Sources

- <https://github.com/bluesky-social/pds>
- <https://atproto.com/specs/account>
- <https://atproto.com/specs/sync>
