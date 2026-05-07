---
title: Milestone 03 - Identity and Handles
specs:
  - ../specs/identity-handles.md
---

Goal: give local accounts resolvable DID and handle metadata.

## Tasks

- [ ] T03-01: Add DID syntax validator.
- [ ] T03-02: Add handle syntax validator.
- [ ] T03-03: Add `signing_keys` table and encrypted private-key storage boundary.
- [ ] T03-04: Generate initial signing key for new accounts.
- [ ] T03-05: Add DID document builder for hosted accounts.
- [ ] T03-06: Add `/.well-known/atproto-did` route for hosted handles.
- [ ] T03-07: Implement DNS TXT handle resolver.
- [ ] T03-08: Implement HTTPS well-known handle resolver with `Req`.
- [ ] T03-09: Add SSRF protection before outbound handle/DID fetches.
- [ ] T03-10: Implement `resolveHandle`.
- [ ] T03-11: Implement `updateHandle` with bidirectional verification.
- [ ] T03-12: Emit identity event placeholder into sequencer once sequencer exists.
- [ ] T03-13: Add integration tests using a fake HTTP handle service.

## Integration Tests

- Local handle resolves to DID.
- DID document claims the handle.
- Invalid handle fails validation.
- Outbound handle verification rejects private IP targets.

## HTTP Verification

```bash
hurl --test --jobs 1 --variable base_url=http://localhost:4000 test/smoke/identity.hurl
```

## Done

Run:

```bash
mix precommit
```
