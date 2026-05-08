---
title: Security, OAuth, and Delegated Access
updated: 2026-05-08
---

# Security, OAuth, and Delegated Access

Tempest should not stop at legacy password sessions. OAuth is the primary long-term authz surface for user-facing atproto clients, and the same permission engine should constrain OAuth tokens, app passwords, and delegated account access.

## Required OAuth Surface

Expose:

```text
/.well-known/oauth-protected-resource
/.well-known/oauth-authorization-server
/oauth/jwks
/oauth/par
/oauth/authorize
/oauth/token
```

Required profile behavior:

- Client IDs are public metadata URLs.
- PAR is required for authorization requests.
- PKCE is required.
- DPoP is required for token-bound requests.
- Authorization responses must include the approved scopes.
- Token responses must include and validate the account DID as `sub`.
- Client metadata fetches must use hardened HTTP with SSRF protection, body limits, timeouts, and no unsafe redirects.
- Unknown client metadata must be displayed conservatively; only trusted clients may show rich names/logos.

## Permission Model

Use one internal permission model for:

- OAuth grants.
- App passwords.
- Account delegation.
- Admin-only account management actions.

Represent permissions as structured records, not string checks scattered through handlers:

```text
actor_did
subject_did
credential_type
scope
resource
action
audience
expires_at
revoked_at
```

Initial compatibility scopes:

- `atproto`
- `transition:generic`
- `transition:chat.bsky`
- `transition:email`
- `blob:*/*`
- `rpc:<nsid>?aud=<did>`

Granular permission support should be added behind the same data model, even if the first UI only exposes coarse choices.

## Account Security

Implement after stable sessions, before calling the PDS production-ready:

- Email confirmation and email update flow.
- Password reset flow with short-lived, single-use tokens.
- Password change requiring current credential or strong reauth.
- MFA credential table that can support TOTP, WebAuthn/passkeys, backup codes, and trusted devices.
- Recovery codes stored hashed, shown once.
- Login/session inventory and remote revoke.
- Security event log for password, email, MFA, OAuth, app password, and delegated-access changes.
- Notification boundary for email first, with room for other channels later.

## App Passwords

Tempest should support app passwords because they remain part of current atproto usage for bots and CLI tools.

Rules:

- Generate high-entropy secrets and store only hashes.
- Show the secret exactly once.
- Names are labels, not credentials.
- Scopes must be at least as restrictive as OAuth.
- Revocation must be immediate for future requests.
- App passwords must not authorize account deletion, email changes, handle changes, PLC operations, or MFA changes.

## Delegated Access

Delegation allows one account to manage another with explicit permission boundaries. Treat it as a separate credential class, not as shared passwords.

Minimum model:

- owner DID
- delegate DID
- role or custom permission set
- approved scopes
- created/revoked timestamps
- optional expiry
- audit log

Delegates must never gain identity recovery or deletion powers unless a later spec explicitly designs those flows with strong reauth.

## Adversarial Checks

- DPoP nonce failures must not silently fall back to bearer semantics.
- A token must be rejected if the `sub`, authorized PDS, and current DID document do not agree.
- SSRF protections apply to OAuth client metadata, logos, JWKS URIs, DID documents, and handle well-known fetches.
- Partial-scope approval must be represented exactly; do not assume all requested scopes were granted.
- Permission checks must be centralized enough that new XRPC methods cannot accidentally bypass them.
- Auth and recovery endpoints need independent rate limits.

## HTTP Verification

```bash
http GET :4000/.well-known/oauth-protected-resource
http GET :4000/.well-known/oauth-authorization-server
http GET :4000/oauth/jwks
http POST :4000/oauth/par DPoP:"$DPOP" client_id="$CLIENT_ID" scope="atproto"
```

Expected:

- Metadata endpoints return protocol-shaped JSON.
- PAR requires DPoP and returns a nonce.
- Unknown client metadata is fetched through the hardened HTTP boundary.
- Approved scopes are preserved in token responses and enforced on XRPC calls.

## Sources

- <https://atproto.com/specs/oauth>
- <https://atproto.com/guides/scopes>
- <https://atproto.com/specs/auth>
- <https://docs.bsky.app/docs/advanced-guides/oauth-client>
