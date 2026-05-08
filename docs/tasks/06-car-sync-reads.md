---
title: Milestone 06 - CAR and Sync Reads
specs:
  - ../specs/repo-core.md
  - ../specs/sync-firehose.md
---

Goal: expose repository state through sync read endpoints.

## Tasks

- [x] T06-01: Implement full repo CAR export from stored blocks.
- [x] T06-02: Set `Content-Type: application/vnd.ipld.car` for `getRepo`.
- [ ] T06-03: Implement `getRepo`.
- [ ] T06-04: Implement `getLatestCommit`.
- [ ] T06-05: Implement `getRecord` in `com.atproto.sync`.
- [ ] T06-06: Implement `getRepoStatus`.
- [ ] T06-07: Implement `listRepos` for hosted accounts.
- [ ] T06-08: Add CAR import verification helper.
- [ ] T06-09: Add integration test that exports and verifies a repo.
- [ ] T06-10: Add restart test for latest commit consistency.

## Integration Tests

- `getRepo` exports a parseable CAR.
- CAR root matches latest commit.
- `getLatestCommit` matches repo metadata.
- Inactive account returns correct repo status.

## HTTP Verification

```bash
hurl --test --jobs 1 --variable base_url=http://localhost:4000 test/smoke/car-sync.hurl
```
