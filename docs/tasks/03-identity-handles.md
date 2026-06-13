---
title: Milestone 03 - Identity and Handles
specs:
  - ../specs/identity-handles.md
---

Completed [May 7, 2026](../../CHANGELOG.md#2026-05-07).

## Verification

```bash
suffix="$(date +%s)"
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  --variable account_handle="identity-${suffix}.test" \
  --variable account_email="identity-${suffix}@example.com" \
  --variable account_password="correct horse battery staple" \
  test/smoke/identity.hurl
```

This milestone covers local identity and handle behavior. Network identity
correctness for hosted DIDs is tracked in Milestone 11.

## Follow-up PLC Endpoint Coverage

The internal PLC client boundary exists, but public PLC identity XRPC endpoints
remain follow-up work:

- [x] Add `com.atproto.identity.getRecommendedDidCredentials` with response-shape,
      auth, and fake-PLC/key-store tests.
- [x] Add `com.atproto.identity.requestPlcOperationSignature` with strong reauth,
      single-use token, audit-log, and error-shape tests.
- [x] Add `com.atproto.identity.signPlcOperation` with operation validation tests
      that reject service-diverting or unrecoverable PLC operations.
- [x] Add `com.atproto.identity.submitPlcOperation` with fake PLC submission,
      failure, idempotency, and migration event-ordering tests.
- [x] Create, sign, and submit PLC operations correctly end-to-end.
- [x] Fetch existing PLC state before building update operations.
- [x] Introduce a stable `TEMPEST_PLC_ROTATION_KEY` configuration path.
- [x] Support an optional account/operator recovery key.
- [x] Derive public `did:key` rotation keys from configured/private key material.
- [x] Ensure repository signing keys are never used as PLC rotation keys.
- [x] Verify `getRecommendedDidCredentials` returns the correct recommended DID
      credential shape once dedicated rotation-key material exists.
- [x] Refresh bundled Lexicons and the PDS compatibility matrix when the handlers
      are registered.
