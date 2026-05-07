---
title: Milestone 08 - Blobs
specs:
  - ../specs/blobs.md
---

Goal: upload, reference, serve, and garbage collect blobs.

## Tasks

- [ ] T08-01: Add blob metadata table to `account.sqlite`.
- [ ] T08-02: Add local blob storage adapter.
- [ ] T08-03: Add blob CID calculation.
- [ ] T08-04: Add upload size validation.
- [ ] T08-05: Add MIME validation/sniffing boundary.
- [ ] T08-06: Implement `uploadBlob`.
- [ ] T08-07: Scan records for blob references during writes.
- [ ] T08-08: Reject new records that reference missing blobs.
- [ ] T08-09: Promote temp blobs after successful record commit.
- [ ] T08-10: Implement `listBlobs`.
- [ ] T08-11: Implement `getBlob`.
- [ ] T08-12: Suppress blob serving for inactive accounts.
- [ ] T08-13: Add blob garbage collector.
- [ ] T08-14: Add integration tests for upload, reference, get, delete.

## Integration Tests

- Upload returns Lexicon blob metadata.
- Temp blob is not listed.
- Referenced blob is listed and downloadable.
- Missing blob reference fails.
- Blob remains after restart.

## HTTP Verification

```bash
hurl --test --jobs 1 --variable base_url=http://localhost:4000 test/smoke/blobs.hurl
```

## Done

Run:

```bash
mix precommit
```
