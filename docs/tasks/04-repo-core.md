---
title: Milestone 04 - Repository Core
specs:
  - ../specs/repo-core.md
---

Goal: build and prove the binary repository primitives before exposing writes broadly.

## Tasks

- [ ] T04-01: Add AT URI parser and tests.
- [ ] T04-02: Add NSID parser and tests.
- [ ] T04-03: Add record-key parser and tests.
- [ ] T04-04: Add TID generator with monotonic per-DID guard.
- [ ] T04-05: Add CID wrapper and known-vector tests.
- [ ] T04-06: Add DRISL CBOR encode/decode boundary.
- [ ] T04-07: Add CBOR decode limits.
- [ ] T04-08: Add CAR v1 reader.
- [ ] T04-09: Add CAR v1 writer.
- [ ] T04-10: Add MST depth calculation tests from official examples.
- [ ] T04-11: Add MST insert/get/delete.
- [ ] T04-12: Add MST range scan.
- [ ] T04-13: Add commit object builder with required `prev`.
- [ ] T04-14: Add commit signing and verification.
- [ ] T04-15: Add repo-core fixture import from official test cases.
- [ ] T04-16: ~~Decide and document whether repo-core stays pure Elixir or uses Rustler.~~ Pure elixir.

## Integration Tests

- Golden vectors pass.
- CAR round trip returns the same root CID.
- Commit signature verifies with the DID document key.

## HTTP Verification

This milestone has no public write endpoint yet. Add a temporary test-only route or skip public exposure until Milestone 05, but the first user-visible verification must be:

```bash
hurl --test --jobs 1 --variable base_url=http://localhost:4000 test/smoke/repo.hurl
```

Expected by Milestone 05:

- The endpoint returns a CID created by this repo-core layer.

## Done

Run:

```bash
mix precommit
```
