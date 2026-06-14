---
title: Public Stats Dashboard
updated: 2026-06-13
---

Tempest exposes aggregate operational data through public routes with no auth. The
dashboard is intended to make a deployment inspectable without exposing sensitive
admin or account details.

## Endpoints

- `GET /stats`
- `GET /xrpc/_stats`

`/stats` is a readable HTML page linked from the homepage. `/xrpc/_stats` is the
stable machine endpoint for scripts, external checks, and deployment smoke tests.

## Runtime data model

The HTML and JSON views share a single source of truth:

- no auth required for read access;
- no caching in the first implementation (fresh aggregation per request);
- `generatedAt` is always included and always reflects the snapshot time used for the
  response.

## `/xrpc/_stats` response contract

```json
{
  "status": "ok",
  "version": "0.1.0",
  "generatedAt": "2026-06-14T19:00:00Z",
  "uptimeSeconds": 86400,
  "metrics": {
    "hostedAccountCount": 2,
    "totalAccountCount": 5,
    "commitCount": 128,
    "collectionCount": 12,
    "recordCount": 2048,
    "lastIndexedAt": "2026-06-14T18:57:11Z"
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

`health.status` is derived from the checks below:

- `ok`: all required checks pass and torn-write count is zero.
- `degraded`: required checks mostly pass but one or more non-critical checks fail.
- `unhealthy`: account DB, sequencer DB, or writable storage checks fail.

## Definitions

- `hostedAccountCount`: count of accounts with `active == true` and
  `status == "active"`.
- `totalAccountCount`: all rows in the account table.
- `commitCount`: sum of row counts from each repo-level `commits` table.
- `collectionCount`: sum of per-repo distinct `collection` values in current record tables.
- `recordCount`: sum of current records in per-repo `records` tables.
- `lastIndexedAt`: latest of repo `records.updated_at`, repo `commits.inserted_at`, and
  sequencer `repo_seq.created_at` where available.

If any repo scan fails during aggregation, the response keeps a valid snapshot for the
rest of the data and flags the error path in `health` for transparency.

## Security

- Public output must not include:
  - emails, passwords, sessions, session IDs
  - app-password values or OAuth token material
  - admin token or config paths
  - backup or filesystem details
  - private signing key material
  - security event metadata
- Public output may include only high-level aggregate counts and aggregate health.

These constraints are enforced in the stats aggregator by reading only sanitized data
from admin status surfaces.

## Notes

- `hostedAccountCount`/`totalAccountCount` are computed from account DB state.
- Commit, collection, and record counts are computed by reading repo DBs for hosted
  accounts.
- Health checks include writable storage and the minimum set of DB/query checks needed for
  confidence in the aggregate response.
- The page is intentionally static and non-interactive; it is not a control panel and
  does not expose admin actions.
