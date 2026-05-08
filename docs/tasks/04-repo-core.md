---
title: Milestone 04 - Repository Core
specs:
  - ../specs/repo-core.md
---

Goal: build and prove the binary repository primitives before exposing writes broadly.

## Tasks

- [x] T04-01: Add AT URI parser and tests.
- [x] T04-02: Add NSID parser and tests.
- [x] T04-03: Add record-key parser and tests.
- [x] T04-04: Add TID generator with monotonic per-DID guard.
- [x] T04-05: Add CID wrapper and known-vector tests.
- [x] T04-06: Add DRISL CBOR encode/decode boundary.
- [x] T04-07: Add CBOR decode limits.
- [x] T04-08: Add CAR v1 reader.
- [x] T04-09: Add CAR v1 writer.
- [x] T04-10: Add MST depth calculation tests from official examples.
- [x] T04-11: Add MST insert/get/delete.
- [x] T04-12: Add MST range scan.
- [ ] T04-13: Add commit object builder with required `prev`.
- [ ] T04-14: Add commit signing and verification.
- [ ] T04-15: Add repo-core fixture import from official test cases.
- [x] T04-16: ~~Decide and document whether repo-core stays pure Elixir or uses Rustler.~~ Pure Elixir.

## Integration Tests

- Golden vectors pass.
- CAR round trip returns the same root CID.
- Commit signature verifies with the DID document key.
