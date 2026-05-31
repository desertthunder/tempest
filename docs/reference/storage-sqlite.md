---
title: SQLite Storage
updated: 2026-05-31
---

Tempest uses SQLite as the default storage backend for a small self-hosted PDS.
The design favors inspectable local files over a required external database.

## Concepts

A PDS stores several kinds of state:

- account/auth state: who can act as whom
- repository state: signed record blocks and commits
- sequencer state: global event order for firehose consumers
- blob state: uploaded bytes and whether records currently reference them

Repository data is public and content-addressed, but account/session keys and
operator secrets are private operational state.

## Data directory

`TEMPEST_DATA_DIR` owns all local persistent state. Development defaults to
`priv/tempest_dev`.

Typical layout:

```text
<TEMPEST_DATA_DIR>/
  account.sqlite
  sequencer.sqlite
  repos/
    <normalized-did>.sqlite
  blobs/
    <normalized-did>/
      <cid>
```

## Databases

`account.sqlite` is managed through Ecto and stores account-oriented state:
accounts, sessions, signing keys, app passwords, OAuth data, and blob metadata.

`sequencer.sqlite` is a raw SQLite database for the monotonic PDS-wide event
sequence. It is the durable source for firehose cursors.

Each hosted DID gets a separate repo database under `repos/`. Repo databases
store blocks, current record indexes, commits, and repo metadata.

## Operational notes

SQLite runs with WAL where configured. Repo writes are serialized per DID and use
explicit transaction boundaries so a record write cannot become visible without
its corresponding commit metadata.

Backups must include `account.sqlite`, `sequencer.sqlite`, `repos/`, `blobs/`,
and any WAL files or checkpointed equivalents.

## Verification

```bash
hurl --test --variable base_url=http://localhost:4000 test/smoke/health.hurl
```

The health response includes the active data directory, account DB, sequencer DB,
and writability status.
