---
title: Security, OAuth, and Delegated Access
updated: 2026-06-19
---

Tempest has three account credential families today:

- legacy account sessions from `createSession`
- OAuth access/refresh tokens issued through PAR and authorization-code exchange
- app passwords for current atproto client and bot compatibility

Delegated access, MFA credentials, backup codes, email tokens, and security
events share the same account-security context so future permission checks can
use one model instead of scattered string checks.

## OAuth surface

Implemented metadata and token routes:

```text
/.well-known/oauth-protected-resource
/.well-known/oauth-authorization-server
/oauth/jwks
/oauth/par
/oauth/authorize
/oauth/token
/oauth/revoke
```

Current OAuth behavior:

- PAR is required before authorization.
- PKCE with `S256` is required.
- DPoP proofs bind issued tokens.
- Confidential OAuth clients can authenticate with `private_key_jwt`.
- Token responses preserve the approved scope string.
- Access tokens include the account DID as the subject boundary.
- Revocation marks matching OAuth token rows revoked.

Client metadata and remote identity fetches go through hardened HTTP boundaries
with SSRF checks, body limits, timeouts, and redirect restrictions.

## OAuth confidential clients

Tempest supports `private_key_jwt` for AT Protocol OAuth confidential clients.
The implementation follows the stricter AT Protocol profile on top of RFC 7523
and OpenID Connect Core:

- client metadata must set `token_endpoint_auth_method: "private_key_jwt"`
- client keys must be public ES256 keys in inline `jwks` or HTTPS `jwks_uri`
- assertions must be sent as `client_assertion` with JWT bearer
  `client_assertion_type`
- `iss` and `sub` must equal the `client_id`
- `aud` must equal Tempest's authorization-server issuer
- `exp`, `iat`, and `jti` are required
- the `kid`, algorithm, JWK thumbprint, and signature must match the current
  client keyset

Tempest stores accepted assertion JTIs by client to reject replay. For
confidential clients, the key used at PAR is also bound to the authorization
code and refresh-token family. Token exchange and refresh re-fetch client
metadata/JWKS and require the same `kid`, `alg`, and JWK thumbprint, so a client
key removed from metadata can no longer refresh that session.

Detailed interoperability notes are in
[`oauth-private-key-jwt`](./oauth-private-key-jwt.md).

## App passwords

App passwords remain important for bots, CLIs, and clients that still use legacy
auth. Tempest generates high-entropy secrets, stores only hashes, and shows the
secret once in the XRPC response. The account UI lists names, scopes, last-use
state, and revocation state, but never the secret or hash.

App passwords must not authorize recovery, deletion, handle changes, PLC changes,
or MFA changes.

## Account security inventory

`Tempest.Security.account_security_inventory/1` gathers the account's security
state for the operator UI:

- sessions and refresh-token family state
- OAuth grants
- app passwords
- delegated-access grants
- MFA credentials
- backup-code summaries
- security event log

The UI is split between `/account/access` and `/account/security` so access
credentials and recovery/MFA state are easy to inspect separately.

## Email and recovery

Email confirmation, email update, and password reset use short-lived hashed email
tokens. Consuming a reset token revokes sessions before the password is changed.
Development email previews are available at `/dev/mailbox` when dev routes are
enabled.

## MFA and backup codes

The MFA table supports TOTP today and has room for passkeys/WebAuthn, backup-code
credentials, and trusted devices. Recovery codes are stored hashed and shown only
when rotated. The UI shows backup-code availability, not code values.

## Verification

```bash
mix test test/tempest/security_test.exs \
  test/tempest_web/controllers/oauth_flow_test.exs \
  test/tempest/oauth/client_metadata_test.exs

hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  test/smoke/oauth-security.hurl
```

The tests cover OAuth metadata, PAR/token/revoke paths, DPoP binding,
`private_key_jwt`, email tokens, security events, TOTP, backup codes,
delegated-access grants, session revocation, app passwords, and rate limiting.
