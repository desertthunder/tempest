---
title: Public Stats Dashboard
updated: 2026-06-14
---

Tempest exposes aggregate operational data through public routes with no auth. The
dashboard makes a deployment inspectable without exposing sensitive admin or
account details.

## Endpoints

- `GET /stats`
- `GET /xrpc/_stats`
- `GET /changelog`

`/stats` is a readable HTML page linked from the homepage. `/xrpc/_stats` is the
stable machine endpoint for scripts, external checks, and deployment smoke tests.
`/changelog` renders `CHANGELOG.md` as a separate public desktop document.

## Runtime data model

The HTML and JSON views share a single source of truth:

- no auth required for read access;
- no caching in the first implementation (fresh aggregation per request);
- `generatedAt` is always included and always reflects the snapshot time used for the
  response;
- bounded detail groups are derived from the same sanitized public stats boundary,
  not from private admin status data in the view layer.

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
  },
  "users": [
    {
      "did": "did:plc:example",
      "handle": "alice.example.com",
      "status": "active",
      "recordCount": 42,
      "lastIndexedAt": "2026-06-14T18:57:11Z",
      "avatarUrl": "/xrpc/com.atproto.sync.getBlob?did=did%3Aplc%3Aexample&cid=baf...",
      "bannerUrl": "/xrpc/com.atproto.sync.getBlob?did=did%3Aplc%3Aexample&cid=baf..."
    }
  ],
  "latestRecord": {
    "did": "did:plc:example",
    "handle": "alice.example.com",
    "collection": "app.bsky.feed.post",
    "rkey": "3k...",
    "cid": "baf...",
    "indexedAt": "2026-06-14T18:57:11Z"
  },
  "commitWeeks": [{ "weekStart": "2026-06-08", "weekEnd": "2026-06-14", "commitCount": 31 }],
  "collections": [{ "collection": "app.bsky.feed.post", "recordCount": 120 }]
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

## Detail groups

Detail groups are intentionally bounded:

- users: 12 active hosted users;
- collections: 10 highest record counts;
- latest record: 1 most recently updated current record;
- commit weeks: latest 4 complete or partial Monday-Sunday ranges.

User cards show handle, DID, active/hosted status, current record count, last
indexed time, and profile imagery when available. Avatar and banner URLs use this
node's existing public blob endpoint and are generated from current
`app.bsky.actor.profile` blob references. The public stats response must not
proxy remote image URLs, expose private blob storage paths, or include full
profile record JSON.

`latestRecord` identifies the most recently indexed current record across active
hosted users with handle or DID, collection, rkey, CID, and indexed timestamp.
The dashboard does not depend on a third-party record viewer.

`commitWeeks` groups commit rows by UTC Monday-Sunday week ranges and includes
zero-count weeks inside the returned range so the visual layout stays stable.

`collections` aggregates records across repos by collection NSID. It sorts by
record count descending, then collection name ascending.

## Security

- Public output must not include:
  - emails, passwords, sessions, session IDs
  - app-password values or OAuth token material
  - admin token or config paths
  - backup or filesystem details
  - private signing key material
  - security event metadata
- Public output may include only high-level aggregate counts and aggregate health.

These constraints are enforced in the stats aggregator by reading only sanitized
data from public stats functions. Leak regression tests cover the expanded JSON
shape.

## Changelog desktop document

`/changelog` exposes `CHANGELOG.md` as a public document view with a retro word
processor presentation. It uses a fixed `Tempest.Docs` desktop-document manifest,
not arbitrary paths from the request.

The changelog renderer:

- renders trusted local Markdown with MDEx;
- parses simple frontmatter if present, but does not require it;
- rejects unknown desktop document slugs and path traversal attempts;
- includes a source view for the raw Markdown body;
- is linked from the home desktop with `priv/static/images/icons/page.svg`;
- uses normal Phoenix/LiveView rendering and no inline scripts.

## Verification

```bash
curl -fsS http://localhost:4000/xrpc/_stats
curl -fsS http://localhost:4000/stats
curl -fsS http://localhost:4000/changelog
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  test/smoke/public-stats.hurl
```
