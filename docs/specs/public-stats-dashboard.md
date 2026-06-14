---
title: Public Stats Dashboard
updated: 2026-06-14
status: implemented; planned expansion
---

Reference documentation: ../reference/public-stats-dashboard.md

## Planned expansion

The next dashboard iteration should move beyond aggregate counters and expose a
small public snapshot of activity on the node:

- user cards
- latest indexed record;
- weekly commit activity, grouped Monday through Sunday;
- collection summaries with per-collection record counts.

The data should come from the same sanitized public stats boundary used by
`/xrpc/_stats` and `/stats`. Do not query private admin status data directly from
the view layer.

## Public data contract

Extend the public stats snapshot with optional detail groups:

```json
{
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

All detail groups should be bounded

- users: 12 active hosted users;
- collections: 10 highest record counts;
- latest record: 1 most recently updated current record;
- commit weeks: latest 8 complete or partial Monday-Sunday ranges.

## User cards

Each user card should show:

- banner image when the user's `app.bsky.actor.profile` record contains a banner
  blob reference;
- avatar image when the profile record contains an avatar blob reference;
- deterministic fallback treatment when either image is missing;
- handle;
- DID in a compact monospace line;
- active/hosted status;
- current record count.

Avatar and banner URLs should use this node's existing public blob endpoint and
must be generated from current profile record blob references. Do not proxy
remote image URLs, do not expose private blob storage paths, and do not include
the full profile record JSON in public stats.

If profile record parsing fails for one user, keep rendering the rest of the
snapshot and count the failure as a public stats scan error.

## Latest indexed record

Show the most recently indexed current record across active hosted users. The
display should include:

- handle or DID;
- collection;
- rkey;
- CID;
- indexed timestamp.

The dashboard may link to a public AT Protocol record viewer later, but the first
version should not depend on a third-party viewer to render correctly.

## Weekly commit activity

Replace the vague "commit graph" idea with a weekly histogram:

- week ranges are Monday through Sunday;
- `weekStart` and `weekEnd` are ISO dates;
- count commits by each repo commit row's `inserted_at`;
- include weeks with zero commits inside the returned range so the visual does
  not jump;
- use UTC for grouping unless a future config explicitly chooses another zone.

The UI should render this as a compact bar chart or segmented strip. It should
remain useful with no JavaScript.

## Collection summaries

Collections should show collection NSID and record count. Sort by record count
descending, then collection name ascending for stable output. If multiple repos
contain the same collection, aggregate them into one row.

## Changelog desktop document

Tempest should also expose `CHANGELOG.md` as a public document view that feels
like a word processor document rather than the existing browser-style docs
viewer.

This should reuse prior markdown rendering infrastructure from `Tempest.Docs`
where practical:

- keep lookup manifest-based, not arbitrary path-based;
- render trusted local Markdown with MDEx;
- parse simple frontmatter only if present, but do not require it;
- avoid rendering user-supplied Markdown;
- preserve the ability to copy or read the raw Markdown if the existing docs
  viewer pattern makes that cheap.

Suggested route:

```text
GET /changelog
```

The home desktop should link to it with `priv/static/images/icons/page.svg` and a
short label such as "Changelog".

The visual design should read as a retro word processor / document window:

- desktop shell consistent with the home and docs pages;
- page icon on the desktop;
- title bar and document toolbar;
- white document canvas with readable typography;
- print-like page width;
- no inline scripts.

Verification:

```bash
curl -fsS http://localhost:4000/xrpc/_stats
curl -fsS http://localhost:4000/stats
curl -fsS http://localhost:4000/changelog
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  test/smoke/public-stats.hurl
```
