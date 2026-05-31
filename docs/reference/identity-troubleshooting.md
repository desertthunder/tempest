---
title: Identity Troubleshooting
updated: 2026-05-31
---

Identity correctness means the local account row, DID document, handle
resolution, and public PDS URL all agree.

## Concepts

An atproto account is identified by a DID. A handle is only valid when it resolves
to that DID and the DID document claims the handle with `alsoKnownAs:
["at://<handle>"]`.

The DID document must include `#atproto_pds` with a service endpoint matching the
Tempest public URL. OAuth clients, relays, and AppViews rely on this endpoint when
they decide which PDS is authoritative for a DID.

## Checks

For a hosted account, verify:

- handle syntax is valid
- DID syntax matches the configured hosted DID method
- `/.well-known/atproto-did` returns the account DID for the handle host
- `com.atproto.identity.resolveHandle` returns the same DID
- the DID document contains `alsoKnownAs: at://<handle>`
- the DID document's `#atproto_pds` service endpoint matches `TEMPEST_PUBLIC_URL`

## Hosted DID modes

`TEMPEST_HOSTED_DID_METHOD=plc` creates `did:plc` accounts. If PLC publishing is
enabled in config, Tempest submits a PLC operation through the PLC client
boundary.

`TEMPEST_HOSTED_DID_METHOD=web` creates a `did:web` identity for the configured
hostname. This is intended for single-user/self-hosted setups where the operator
controls the domain.

## Verification

```bash
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  test/smoke/identity-correctness.hurl
```
