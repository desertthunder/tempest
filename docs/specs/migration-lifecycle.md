---
title: Migration and Account Lifecycle
updated: 2026-05-31
status: implemented
---

# Migration and Account Lifecycle

Reference documentation: ../reference/migration-lifecycle.md

Account portability is a core atproto property. Tempest must support both normal account hosting and migration flows without relying on a cooperative old PDS forever.

## Account Lifecycle Endpoints

Implement:

```text
com.atproto.server.checkAccountStatus
com.atproto.server.activateAccount
com.atproto.server.deactivateAccount
com.atproto.server.requestAccountDelete
com.atproto.server.deleteAccount
com.atproto.server.getServiceAuth
com.atproto.server.reserveSigningKey
com.atproto.identity.getRecommendedDidCredentials
com.atproto.identity.requestPlcOperationSignature
com.atproto.identity.signPlcOperation
com.atproto.identity.submitPlcOperation
```

Email-related account flows belong here operationally even when implemented under the auth context:

```text
com.atproto.server.confirmEmail
com.atproto.server.requestEmailConfirmation
com.atproto.server.requestEmailUpdate
com.atproto.server.updateEmail
com.atproto.server.requestPasswordReset
com.atproto.server.resetPassword
```

## PLC Endpoint Compatibility

Migration-in and migration-out require public coverage for these identity XRPC
methods in addition to the internal PLC client boundary:

```text
com.atproto.identity.getRecommendedDidCredentials
com.atproto.identity.requestPlcOperationSignature
com.atproto.identity.signPlcOperation
com.atproto.identity.submitPlcOperation
```

Tests must use a fake PLC service and prove that invalid, unsigned, stale, or
service-diverting operations fail closed. Successful submissions must preserve
rotation-key recoverability, keep `#atproto_pds` pointed at Tempest when the
account is active here, and emit/audit identity lifecycle changes in migration
order.

## Migration Flow

Supported happy path:

1. Create an account for an existing DID with proof of identity control or service auth.
2. Store it initially as `active=false`, `status=deactivated`.
3. Import the old repo CAR through `com.atproto.repo.importRepo`.
4. Index records and compute missing blobs.
5. Download/upload blobs after repo import, using `listBlobs` and `listMissingBlobs`.
6. Fetch recommended DID credentials from Tempest.
7. Update PLC or `did:web` identity so the DID document points at Tempest.
8. Activate the account on Tempest.
9. Emit `#identity`, `#account`, and `#sync` or `#commit` events in spec-valid order.
10. Optionally deactivate/delete the old account.

## Import Safety

`importRepo` must:

- Verify CAR structure and commit root.
- Verify the DID matches the account being imported.
- Verify commit signatures against the identity state that is valid for the imported revision.
- Preserve revision monotonicity; new commits after import must be higher than the imported latest revision.
- Index all record paths and CIDs before activation.
- Record missing blobs rather than accepting new writes that reference unknown blobs.
- Fail atomically: no half-imported active account.

## Account Status Semantics

`active=false` suppresses repository exports, repo record reads, blob serving, and commit/sync redistribution. Identity metadata and account status may still be visible.

Known statuses:

```text
active
deactivated
deleted
takendown
suspended
desynchronized
throttled
```

`checkAccountStatus` should report repo, blob, indexed-record, missing-blob, and migration-readiness counts for the authenticated account.

## Event Ordering

Account creation should emit:

```text
#identity
#account
#commit or #sync
```

Migration activation should emit:

```text
#identity
#account active=true
#sync or #commit with latest imported state and monotonic rev
```

Deactivation/deletion should emit `#account active=false` before public content is redistributed again.

## Adversarial Checks

- Do not activate an account before the DID document points at this PDS.
- Do not accept service auth for an endpoint, audience, or DID it was not issued for.
- Do not let imported records bypass lexicon validation unless explicitly running in a lossless import mode that still stores validation failures.
- Do not garbage-collect migration blobs too early; imports may need delayed blob upload.
- Do not reuse old sequence numbers after restore or import.
- Broken identity update flows must fail closed; a bad PLC operation can strand an account.

## HTTP Verification

```bash
http GET :4000/xrpc/com.atproto.server.checkAccountStatus "Authorization:Bearer $TOKEN"
http GET :4000/xrpc/com.atproto.server.getServiceAuth aud==did:web:tempest.example.com lxm==com.atproto.repo.importRepo "Authorization:Bearer $TOKEN"
http POST :4000/xrpc/com.atproto.repo.importRepo "Authorization:Bearer $TOKEN" < repo.car
http GET :4000/xrpc/com.atproto.repo.listMissingBlobs "Authorization:Bearer $TOKEN"
http POST :4000/xrpc/com.atproto.server.activateAccount "Authorization:Bearer $TOKEN"
```

Expected:

- Imported repo is inactive until identity and activation checks pass.
- Missing blobs are tracked explicitly.
- Activation emits account and sync events.
- Inactive accounts cannot serve repo CAR or blobs.

## Sources

- <https://atproto.com/specs/account>
- <https://atproto.com/guides/account-migration>
- <https://atproto.com/specs/sync>
