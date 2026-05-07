---
title: Identity and Handles
updated: 2026-05-07
---

# Identity and Handles

Identity is rooted in DIDs. Handles are mutable DNS names that must resolve back to the DID, while the DID document must claim the handle.

## DID Support

Supported methods:

- `did:plc` for normal hosted accounts.
- `did:web` for development and explicit import/migration cases.

Tempest must distinguish invalid DID syntax, unsupported DID method, and supported method resolution failure.

## DID Document Requirements

The DID document must expose:

- `id`: the DID.
- `alsoKnownAs`: an `at://<handle>` claim when a handle is known.
- `verificationMethod`: an atproto signing key using `Multikey` when possible.
- `service`: `#atproto_pds` with type `AtprotoPersonalDataServer`.

The PDS service endpoint should be only scheme, host, and optional port. Avoid userinfo, paths, and query strings.

## Handle Verification

Supported handle resolution methods:

- DNS TXT record.
- HTTPS `/.well-known/atproto-did`.

Verification requires both directions:

```text
handle -> DID
DID document -> at://handle
```

Use `Req` for outbound HTTP and apply SSRF protections before fetching any URL derived from identity metadata.

## PLC Operations

Initial implementation may use a PLC client boundary:

```text
Tempest.Identity.PlcClient
Tempest.Identity.PlcOperation
Tempest.Identity.KeyStore
```

The boundary must make it possible to test against a fake PLC service.

## Adversarial Checks

- Never trust a handle only because it is stored locally.
- Do not follow redirects to local, private, or link-local addresses.
- Preserve signing key material securely; avoid logging private keys.
- Key rotation must create a new repository commit so the current signing key can verify the latest repo state.

## HTTP Verification

```bash
http GET :4000/.well-known/atproto-did Host:alice.test
http GET :4000/xrpc/com.atproto.identity.resolveHandle handle==alice.test
http POST :4000/xrpc/com.atproto.identity.updateHandle \
  "Authorization:Bearer $TOKEN" handle=alice.test
```

Expected:

- Well-known handle route returns the DID as plain text.
- `resolveHandle` returns the DID.
- `updateHandle` updates local identity only after bidirectional verification.

## Sources

- <https://atproto.com/specs/did>
- <https://atproto.com/specs/handle>
- <https://atproto.com/guides/identity>
- <https://github.com/did-method-plc/did-method-plc>
