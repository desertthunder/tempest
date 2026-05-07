---
title: Milestone 10 - Compatibility Hardening
specs:
  - ../specs/interop-testing.md
---

Goal: close protocol gaps and verify behavior against external clients, fixtures, and network expectations.

## Tasks

- [ ] T10-01: Sync local Lexicons from the official atproto repository.
- [ ] T10-02: Add Lexicon manifest with source commit or CID metadata.
- [ ] T10-03: Add generated or interpreted validation for all implemented endpoints.
- [ ] T10-04: Add `com.atproto.repo.applyWrites`.
- [ ] T10-05: Add `com.atproto.repo.importRepo`.
- [ ] T10-06: Add app password endpoints.
- [ ] T10-07: Add invite-code endpoints if account creation requires invites.
- [ ] T10-08: Add account lifecycle endpoints needed for deactivate/delete/takedown.
- [ ] T10-09: Add rate limits for auth, record writes, blob uploads, and identity lookups.
- [ ] T10-10: Add interop fixture test suite.
- [ ] T10-11: Add SDK compatibility smoke tests.
- [ ] T10-12: Add migration/import tests.
- [ ] T10-13: Add abuse cases for oversized records, deep CBOR, and invalid CIDs.
- [ ] T10-14: Add external relay/AppView verification notes.

## Integration Tests

- Official fixtures pass.
- Known SDK can log in and write records.
- Invalid repo imports fail safely.
- Rate-limited requests return protocol-shaped errors.

## HTTP Verification

```bash
script/smoke/tempest_basic.sh http://localhost:4000
script/smoke/tempest_compat.sh http://localhost:4000
```

Expected:

- Both smoke scripts exit successfully.
- Output includes account DID, latest commit, exported CAR size, blob CID, and observed firehose seq.

## Done

Run:

```bash
mix precommit
```
