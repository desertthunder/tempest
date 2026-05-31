---
title: Milestone 10 - Compatibility Hardening
specs:
  - ../specs/interop-testing.md
---

Goal: close protocol gaps and verify behavior against external clients, fixtures, and network expectations.

## Tasks

- [x] T10-01: Sync local Lexicons from the official atproto repository.
- [x] T10-02: Add Lexicon manifest with source commit or CID metadata.
- [x] T10-03: Add generated or interpreted validation for all implemented endpoints.
- [x] T10-04: Add `com.atproto.repo.applyWrites`, including same-rkey duplicate semantics.
- [x] T10-05: Add `com.atproto.sync.getBlocks`.
- [x] T10-06: Add `com.atproto.sync.requestCrawl`.
- [x] T10-07: Add `app.bsky.actor.getPreferences` and `app.bsky.actor.putPreferences` for private preference migration compatibility.
- [x] T10-08: Add XRPC proxy fallback rules for service endpoints that should be proxied, not locally implemented.
- [x] T10-09: Add interop fixture test suite.
- [/] T10-10: Add Hurl compatibility smoke tests and keep them passing.
- [x] T10-11: Add migration/import tests that hand off to Milestone 12.
- [x] T10-12: Add abuse cases for oversized records, deep CBOR, invalid CIDs, malformed CAR, and invalid firehose frames.
- [x] T10-13: Add external relay/AppView verification notes.

## Integration Tests

- Official fixtures pass.
- Known SDK can log in and write records.
- Invalid repo imports fail safely.
- Rate-limited requests return protocol-shaped errors.

## HTTP Verification

```bash
hurl --test --jobs 1 --variable base_url=http://localhost:4000 test/smoke/tempest_basic.hurl
hurl --test --jobs 1 --variable base_url=http://localhost:4000 test/smoke/tempest_compat.hurl
```

Expected:

- Both Hurl smoke tests exit successfully.
- Output includes account DID, latest commit, exported CAR size, blob CID, and observed firehose seq.

Known gap:

- `test/smoke/tempest_compat.hurl` currently needs behavior alignment for
  `com.atproto.sync.requestCrawl`.
