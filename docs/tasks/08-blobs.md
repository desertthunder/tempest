---
title: Milestone 08 - Blobs
specs:
  - ../specs/blobs.md
---

Goal: upload, reference, serve, and garbage collect blobs.

## Tasks

- [x] T08-01: Add blob metadata table to `account.sqlite`.
- [x] T08-02: Add local blob storage adapter.
- [x] T08-03: Add blob CID calculation.
- [x] T08-04: Add upload size validation.
- [x] T08-05: Add MIME validation/sniffing boundary.
- [ ] T08-06: Implement `uploadBlob`.
- [ ] T08-07: Scan records for blob references during writes.
- [ ] T08-08: Reject new records that reference missing blobs.
- [ ] T08-09: Promote temp blobs after successful record commit.
- [ ] T08-10: Implement `listBlobs`.
- [ ] T08-11: Implement `getBlob`.
- [ ] T08-12: Suppress blob serving for inactive accounts.
- [ ] T08-13: Add blob garbage collector.
- [ ] T08-14: Add integration tests for upload, reference, get, delete.
- [ ] T08-15: Add CSP and nosniff headers to `getBlob`.
- [ ] T08-16: Add S3-compatible storage behavior and local adapter contract tests.
- [ ] T08-17: Add optional CDN redirect behavior with inactive-account suppression.

## Integration Tests

- Upload returns Lexicon blob metadata.
- Temp blob is not listed.
- Referenced blob is listed and downloadable.
- Missing blob reference fails.
- Blob remains after restart.
- Blob downloads use defensive content headers.
- S3/CDN mode preserves account-status enforcement.

## HTTP Verification

```bash
hurl --test --jobs 1 --variable base_url=http://localhost:4000 test/smoke/blobs.hurl
```
