---
title: Milestone 12 - Migration and Account Lifecycle
specs:
  - ../specs/migration-lifecycle.md
  - ../specs/identity-handles.md
  - ../specs/sync-firehose.md
---

Completed [May 31, 2026](../../CHANGELOG.md#2026-05-31).

## Verification

```bash
mix test
hurl --test --jobs 1 --variable base_url=http://localhost:4000 \
  test/smoke/migration-lifecycle.hurl
```

The smoke test verifies account status, service auth, exported CAR reads, bad CAR
import rejection, missing-blob listing, deactivation suppression, activation,
and account deletion. ExUnit covers migrated DID creation, atomic imports,
post-import revision monotonicity, activation event ordering, unavailable old PDS
failure, and self-controlled `did:web` activation.

Reference documentation: [Migration and Account Lifecycle](../reference/migration-lifecycle.md).

## Follow-up PLC Migration Endpoint Coverage

- [ ] Cover migration-out through `com.atproto.identity.getRecommendedDidCredentials`,
      `requestPlcOperationSignature`, `signPlcOperation`, and
      `submitPlcOperation` using a fake PLC service.
- [ ] Prove PLC operations cannot activate or migrate accounts unless the DID
      document preserves recoverability and points `#atproto_pds` at the intended
      service endpoint.
- [ ] Add black-box tests for PLC endpoint auth: session bearer allowed with
      strong reauth; app passwords, ordinary OAuth tokens, admin tokens, and
      missing credentials denied.
