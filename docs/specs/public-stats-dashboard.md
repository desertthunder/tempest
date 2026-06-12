---
title: Public Stats Dashboard
updated: 2026-06-12
status: planned
---

Tempest is an experimental PDS, so aggregate operational statistics can be public.
The public dashboard should make the node feel inspectable without exposing account
secrets, auth material, private tokens, internal filesystem paths, or per-user admin
controls.

Reference documentation:

- [Admin Operations](./admin-operations.md)
- [Deployment and Observability](./deployment-observability.md)
- [Sync and Firehose](./sync-firehose.md)
- [SQLite Storage](./storage-sqlite.md)

## Goals

- Publish a public, no-auth stats page for the node.
- Publish a small public JSON stats endpoint for automation and badges.
- Reuse existing SQLite, sequencer, and storage status data before adding new
  persistence.
- Keep the private admin dashboard for maintenance actions, backups, repo import,
  repo export, and sensitive paths.
- Make freshness visible: users should know when the stats were computed and what
  `lastIndexedAt` means.

## Non-goals

- No public account emails, app passwords, sessions, OAuth grants, security events,
  backup paths, admin token state, or raw local filesystem paths.
- No unauthenticated admin actions.
- No promise of hosted-provider scale metrics. Initial implementation may scan
  per-repo SQLite files on request or with a short cache.
- No external analytics dependency is required for the first version.

## Public surfaces

### HTML dashboard

Add a public route, preferably:

```text
GET /stats
```

The page should be linked from the home page and can use the existing Tempest visual
system. It should show high-level cards first, then optional detail tables.

### JSON endpoint

Add a public route, preferably:

```text
GET /xrpc/_stats
```

The response should be stable enough for scripts but explicitly project-local, not
an AT Protocol standard endpoint.

Example shape:

```json
{
  "status": "ok",
  "version": "0.1.0",
  "generatedAt": "2026-06-12T19:00:00Z",
  "uptimeSeconds": 86400,
  "metrics": {
    "hostedAccountCount": 3,
    "totalAccountCount": 4,
    "commitCount": 128,
    "collectionCount": 12,
    "recordCount": 2048,
    "lastIndexedAt": "2026-06-12T18:57:11Z"
  },
  "health": {
    "status": "ok",
    "checks": {
      "storageWritable": true,
      "accountDatabase": "ok",
      "sequencerDatabase": "ok",
      "repoDirectory": "ok",
      "blobDirectory": "ok",
      "sequencerReadable": true,
      "tornWriteCount": 0
    }
  }
}
```

## Metric definitions

### `hostedAccountCount`

Count accounts where the account is hosted and active on this PDS. For the current
schema, use accounts with:

```elixir
account.active == true and account.status == "active"
```

### `totalAccountCount`

Count all account rows, including deactivated, suspended, takendown, and deleted
states. This helps explain why totals may differ from hosted active accounts.

### `commitCount`

Initial definition: sum the number of rows in each hosted repo SQLite `commits`
table.

A later version may also expose `sequencedCommitCount` from the global sequencer:

```sql
SELECT COUNT(*) FROM repo_seq WHERE event_type = '#commit'
```

If both are displayed, label them clearly:

- repo commits: commits present in per-account repo stores
- sequenced commits: commit events published to the firehose sequence

### `collectionCount`

Initial definition: sum the number of distinct current record collections across
hosted repos:

```sql
SELECT COUNT(DISTINCT collection) FROM records
```

This counts collections per repo. If two accounts both have `app.bsky.feed.post`,
the aggregate count increases by two. A later dashboard can also show global unique
collection NSIDs.

### `recordCount`

Count current records in per-repo `records` tables:

```sql
SELECT COUNT(*) FROM records
```

Deleted historical records are not counted unless a future historical event metric
is added.

### `lastIndexedAt`

For this project dashboard, `lastIndexedAt` means the newest timestamp at which the
PDS accepted, imported, committed, or sequenced repo-visible data.

Initial implementation should compute the max of available timestamps:

- newest `records.updated_at` across repo DBs
- newest `commits.inserted_at` across repo DBs
- newest `repo_seq.created_at` from the sequencer DB

The dashboard should label this as "last indexed" but include helper text:

> Latest local repo, commit, or sequencer activity observed by this PDS.

## Health definitions

Health should be public and conservative. It should not disclose private local
paths in production.

Statuses:

- `ok`: required storage and DB checks pass and torn writes are zero.
- `degraded`: service can respond, but a non-critical check failed or one or more
  repo DBs could not be scanned for stats.
- `unhealthy`: account DB, sequencer DB, or writable storage checks fail.

Recommended checks:

- account DB exists and can answer a simple query
- sequencer DB exists and can answer `current_seq`
- data directory is writable
- repo directory exists
- blob directory exists
- torn write count is zero
- stats scan error count is zero or explicitly reported

## Privacy and safety

Public stats may include:

- aggregate counts
- public DIDs and handles only if a detail table is explicitly designed for that
  purpose
- repo status values already visible through public protocol behavior
- public health summary

Public stats must not include:

- emails
- password/session/token/OAuth state
- admin token configuration
- backup paths
- raw local filesystem paths in production
- private key state
- security event metadata

## Implementation notes

Prefer a new context boundary such as `Tempest.PublicStats` or a narrow function
under `Tempest.Admin` that returns sanitized public data. The admin status map is
close to the required data, but it contains fields that should not be copied to a
public endpoint without filtering.

Recommended first pass:

1. Extend `Tempest.RepoStorage.status_counts/2` or add a sibling function that
   returns `record_count`, `commit_count`, `collection_count`, and latest relevant
   timestamps for one repo.
2. Add an aggregate public stats function that scans active accounts and folds the
   per-repo stats.
3. Add uptime tracking using application start monotonic time.
4. Add `/xrpc/_stats` JSON.
5. Add `/stats` HTML.
6. Add tests and Hurl smoke coverage.

If request-time scans become expensive, add a supervised cache with a short TTL
such as 5-30 seconds. The JSON response should include `generatedAt` so clients can
judge freshness.

## HTTP verification

```bash
curl -fsS http://localhost:4000/xrpc/_stats
curl -fsS http://localhost:4000/stats
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  test/smoke/public-stats.hurl
```
