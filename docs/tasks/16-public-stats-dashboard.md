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
- [x] T16-11: Add ConnCase tests for `/stats` and `/xrpc/_stats` without admin
      authorization.
- [x] T16-12: Add regression tests proving public stats do not include email,
      token, session, OAuth, backup path, admin token, or private filesystem data.
- [x] T16-13: Add Hurl smoke test `test/smoke/public-stats.hurl`.
- [x] T16-14: Document cache behavior if stats are cached. Include `generatedAt`
      in the JSON response either way.
- [ ] T16-15: Rename the public account detail concept to "users".
- [ ] T16-16: Add the public `users` group described in the stats spec.
- [ ] T16-17: Add public avatar and banner support for user cards.
- [ ] T16-18: Render user cards on `/stats`.
- [ ] T16-19: Add the public `latestRecord` group described in the stats spec.
- [ ] T16-20: Render a "Latest Indexed Record" section on `/stats`.
- [ ] T16-21: Add repo storage support for weekly commit counts.
- [ ] T16-22: Add the public `commitWeeks` group described in the stats spec.
- [ ] T16-23: Render a compact weekly commit histogram on `/stats`.
- [ ] T16-24: Add repo storage support for collection summaries.
- [ ] T16-25: Add the public `collections` group described in the stats spec.
- [ ] T16-26: Render collection summary rows on `/stats` with count bars.
- [ ] T16-27: Extend public stats tests for `users`, avatar/banner URLs,
      `latestRecord`, `commitWeeks`, and collection summaries.
- [ ] T16-28: Extend leak regression tests for the expanded public stats shape.
- [ ] T16-29: Extend `test/smoke/public-stats.hurl` to cover the new JSON fields
      and `/stats` sections.
- [ ] T16-30: Add the public changelog document route described in the stats
      spec.
- [ ] T16-31: Keep changelog source lookup constrained to a fixed manifest entry.
- [ ] T16-32: Style `/changelog` as a word processor document window.
- [ ] T16-33: Link `/changelog` from the desktop shortcuts.
- [ ] T16-34: Add ConnCase coverage for `/changelog`, its desktop shortcut, and
      rejection of arbitrary file/path rendering.
- [ ] T16-35: Add a changelog smoke check to the public stats or docs smoke
      suite, depending on where the route is implemented.

## Integration Tests

- Public stats JSON works without an admin token.
- Public stats HTML works without an admin token.
- Admin-only status remains protected by the existing admin auth checks.
- Counts reflect created accounts and repo writes in an isolated test database.
- Health reports degraded or unhealthy when a required check is forced to fail.
- Public responses omit sensitive fields.
- Expanded public stats match the data contract in
  `docs/specs/public-stats-dashboard.md`.
- `/changelog` renders `CHANGELOG.md` publicly and is linked from the desktop.

## HTTP Verification

```bash
curl -fsS http://localhost:4000/xrpc/_stats
curl -fsS http://localhost:4000/stats
curl -fsS http://localhost:4000/changelog
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  test/smoke/public-stats.hurl
```

## Implementation Notes

Prefer simple request-time aggregation first. If it becomes slow, add a short TTL
cache and keep the response honest with `generatedAt`.

Current behavior: public stats are generated on each request and are not cached.
Every JSON response includes `generatedAt`, the UTC timestamp for that response's
request-time snapshot. If a short TTL cache is added later, `generatedAt` must
remain the timestamp for the cached snapshot, not the time a client receives it.

Detailed data contracts, UI behavior, and privacy rules live in
`docs/specs/public-stats-dashboard.md`.
