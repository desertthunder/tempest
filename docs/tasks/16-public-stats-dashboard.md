---
title: Milestone 16 - Public Stats Dashboard
specs:
  - ../specs/public-stats-dashboard.md
  - ../specs/deployment-observability.md
  - ../specs/admin-operations.md
references:
  - ../reference/deployment-observability.md
  - ../reference/admin-operations.md
---

Goal: expose safe public aggregate stats for the experimental Tempest PDS while
keeping admin-only operations and sensitive internals private.

- [x] T16-01: Add a public stats context or sanitized stats function.
      It should not reuse the full private admin status response directly.
- [x] T16-02: Extend repo stats to include per-repo `commit_count`,
      `collection_count`, and latest repo activity timestamps.
- [x] T16-03: Add aggregate counts for hosted accounts, total accounts, commits,
      collections, records, and `lastIndexedAt`.
- [x] T16-04: Add application uptime tracking based on monotonic time recorded at
      application start.
- [x] T16-05: Add a public health summary with `ok`, `degraded`, and `unhealthy`
      states.
- [x] T16-06: Add `GET /xrpc/_stats` returning sanitized public JSON.
- [x] T16-07: Add `GET /stats` public HTML dashboard.
- [x] T16-08: Link the public stats dashboard from the home page.
- [x] T16-09: Add dashboard cards for hosted accounts, commits, collections,
      records, last indexed, uptime, and health.
- [x] T16-10: Add helper copy explaining that `lastIndexedAt` is local repo,
      commit, or sequencer activity observed by this PDS.
- [ ] T16-11: Add ConnCase tests for `/stats` and `/xrpc/_stats` without admin
      authorization.
- [ ] T16-12: Add regression tests proving public stats do not include email,
      token, session, OAuth, backup path, admin token, or private filesystem data.
- [ ] T16-13: Add Hurl smoke test `test/smoke/public-stats.hurl`.
- [ ] T16-14: Document cache behavior if stats are cached. Include `generatedAt`
      in the JSON response either way.

## Integration Tests

- Public stats JSON works without an admin token.
- Public stats HTML works without an admin token.
- Admin-only status remains protected by the existing admin auth checks.
- Counts reflect created accounts and repo writes in an isolated test database.
- Health reports degraded or unhealthy when a required check is forced to fail.
- Public responses omit sensitive fields.

## HTTP Verification

```bash
curl -fsS http://localhost:4000/xrpc/_stats
curl -fsS http://localhost:4000/stats
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  test/smoke/public-stats.hurl
```

## Implementation Notes

Prefer simple request-time aggregation first. If it becomes slow, add a short TTL
cache and keep the response honest with `generatedAt`.

Suggested JSON shape:

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
