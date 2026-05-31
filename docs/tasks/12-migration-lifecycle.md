---
title: Milestone 12 - Migration and Account Lifecycle
specs:
  - ../specs/migration-lifecycle.md
  - ../specs/identity-handles.md
  - ../specs/sync-firehose.md
---

Goal: support safe account migration, recovery, and lifecycle state propagation.

## Tasks

- [x] T12-01: Implement `checkAccountStatus` with repo, record, blob, and missing-blob counts.
- [x] T12-02: Implement `getServiceAuth` with audience and Lexicon method constraints.
- [x] T12-03: Implement `reserveSigningKey`.
- [x] T12-04: Extend `createAccount` to accept existing DID plus service-auth proof.
- [x] T12-05: Ensure migrated accounts start as `deactivated`.
- [x] T12-06: Harden `importRepo` with CAR, DID, commit signature, and atomicity checks.
- [x] T12-07: Ensure post-import revisions remain monotonic.
- [ ] T12-08: Implement `listMissingBlobs` from indexed imported records.
- [ ] T12-09: Implement `activateAccount` with DID-document/PDS-location verification.
- [ ] T12-10: Implement `deactivateAccount`.
- [ ] T12-11: Implement `requestAccountDelete` and `deleteAccount`.
- [ ] T12-12: Emit account, identity, sync, and commit events in migration-safe order.
- [ ] T12-13: Add migration Hurl suite using exported CAR fixtures.
- [ ] T12-14: Add recovery-path tests for unavailable old PDS and self-controlled `did:web`.

## Integration Tests

- Imported account cannot serve repo or blobs until activated.
- Bad service auth fails.
- Bad CAR import leaves no active partial repo.
- Activation emits `#account active=true` and a sync event.
- Deactivation suppresses repo exports, record reads, blobs, and commit events.

## HTTP Verification

```bash
hurl --test --jobs 1 --variable base_url=http://localhost:4000 test/smoke/migration-lifecycle.hurl
```
