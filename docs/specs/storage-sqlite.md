---
title: SQLite Storage
updated: 2026-05-07
---

# SQLite Storage

SQLite is the default storage design for a self-hosted Tempest PDS. The official PDS distribution is operationally SQLite-oriented, and the self-host target is one to twenty users.

## Data Directory

Default layout:

```text
/var/lib/tempest/
  account.sqlite
  sequencer.sqlite
  repos/
    did_plc_<identifier>.sqlite
  blobs/
    did_plc_<identifier>/
      <cid>
  tmp/
  backups/
```

Development and test must use an isolated `TEMPEST_DATA_DIR`.

## Databases

### `account.sqlite`

Owns account, identity, auth, blob metadata, and admin tables.

Core tables:

```text
accounts
sessions
app_passwords
signing_keys
handle_verifications
blobs
admin_audit_events
```

### `sequencer.sqlite`

Owns the monotonic PDS-wide event sequence.

Core table:

```text
repo_seq
```

Fields:

```text
seq integer primary key autoincrement
did text not null
event_type text not null
rev text
commit_cid text
event_cbor blob not null
created_at text not null
```

### Per-DID Repo Databases

Own records and repo blocks for one hosted account.

Core tables:

```text
blocks
records
commits
repo_metadata
```

## SQLite Settings

- Enable WAL mode.
- Set a busy timeout.
- Keep write transactions short.
- Serialize repo mutations per DID.
- Use explicit transaction boundaries for repo writes.
- Use SQLite backup APIs or a maintenance mode for backups.

## Ecto Boundary

Use Ecto for `account.sqlite` and simple admin metadata. Repo-core storage may use `ecto_sqlite3`, `Exqlite`, or a small storage adapter if block operations need tighter control. Do not hide byte-level repo invariants behind generic schemas.

## Adversarial Checks

- A crashed process must not leave a partially created account with no repo metadata.
- A repo write must not commit without the corresponding sequence event.
- Backup docs must include WAL checkpoint behavior.
- Test databases must never point at the developer's real PDS data directory.

## HTTP Verification

```bash
curl -fsS http://localhost:4000/xrpc/_health
http GET :4000/xrpc/_health
```

Expected once storage bootstrapping is implemented:

- Health response includes `dataDir`, `accountDb`, `sequencerDb`, and `writable`.
- The endpoint must not expose secrets or full private paths in production mode.

## Sources

- <https://github.com/bluesky-social/pds>
- <https://atproto.com/specs/account>
- <https://atproto.com/specs/sync>
