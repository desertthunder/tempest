---
title: Milestone 05 - Record APIs
specs:
  - ../specs/record-apis.md
---

Goal: persist records in per-account repositories and expose repository XRPC reads and writes.

## Tasks

- [x] T05-01: Add per-DID repo database creation.
- [x] T05-02: Add `blocks` table.
- [x] T05-03: Add `records` table.
- [x] T05-04: Add `commits` table.
- [x] T05-05: Add `repo_metadata` table.
- [x] T05-06: Initialize empty repo on account creation.
- [x] T05-07: Implement record Lexicon validation boundary.
- [x] T05-08: Implement `createRecord`.
- [x] T05-09: Implement duplicate-rkey conflict handling.
- [x] T05-10: Implement `putRecord`.
- [x] T05-11: Implement `swapRecord` and `swapCommit`.
- [x] T05-12: Implement `deleteRecord`.
- [x] T05-13: Implement `getRecord`.
- [x] T05-14: Implement `listRecords` with pagination.
- [x] T05-15: Implement `describeRepo`.
- [x] T05-16: Add restart persistence integration test.

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
