# Parking Lot (TODO)

## DPoP Signature Verification

- Add {:jose, "~> 1.11"}.
- In Tempest.OAuth.Dpop.verify_proof/4:
  - parse protected header
  - require typ: "dpop+jwt" when present
  - require alg allowlist, probably start with ES256
  - require embedded public jwk
  - verify JWS signature using that JWK
  - only then validate htm, htu, iat, jti, nonce, and bound jkt
- Tighten supported keys:
  - probably P-256 / ES256 first
  - Verify & Test ES384, ES512, RS256, PS256
- Add negative tests:
  - modified payload fails
  - wrong key fails
  - wrong alg fails
  - reused nonce fails
  - wrong htu / htm fails

## Service Auth Interop

Production service auth needs to be an atproto-compatible JWT:

- signed by the account’s atproto signing key
- iss = account DID
- sub = account DID
- aud = target PDS server DID / audience
- lxm = method, e.g. com.atproto.server.createAccount
- includes expiry / issued-at
- verifiable by another PDS after resolving the DID document

So we need to replace Phoenix.Token service-auth with real JWS
signing, likely ES256K using the account signing key, and implement
verifier logic for inbound migration service auth by resolving the
DID document and checking the #atproto verification method.

## DID/PLC

- stable TEMPEST_PLC_ROTATION_KEY
- optional recovery key
- derive public did:key rotation keys
- create/sign/submit PLC operations correctly
- fetch existing PLC state for updates
- never use repo signing key as the rotation key
- expose correct recommended DID credentials
