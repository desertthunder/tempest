---
title: Milestone 05 - Record APIs
specs:
  - ../specs/record-apis.md
---

Goal: persist records in per-account repositories and expose repository XRPC reads and writes.

## Tasks

- [ ] T05-01: Add per-DID repo database creation.
- [ ] T05-02: Add `blocks` table.
- [ ] T05-03: Add `records` table.
- [ ] T05-04: Add `commits` table.
- [ ] T05-05: Add `repo_metadata` table.
- [ ] T05-06: Initialize empty repo on account creation.
- [ ] T05-07: Implement record Lexicon validation boundary.
- [ ] T05-08: Implement `createRecord`.
- [ ] T05-09: Implement duplicate-rkey conflict handling.
- [ ] T05-10: Implement `putRecord`.
- [ ] T05-11: Implement `swapRecord` and `swapCommit`.
- [ ] T05-12: Implement `deleteRecord`.
- [ ] T05-13: Implement `getRecord`.
- [ ] T05-14: Implement `listRecords` with pagination.
- [ ] T05-15: Implement `describeRepo`.
- [ ] T05-16: Add restart persistence integration test.

## Integration Tests

- Create/get/list profile record.
- Duplicate create fails.
- Put with wrong `swapRecord` fails.
- Delete removes record from get/list.
- Records survive restart.

## HTTP Verification

```bash
hurl --test --jobs 1 --variable base_url=http://localhost:4000 test/smoke/records.hurl
```

## Done

Run:

```bash
mix precommit
```
