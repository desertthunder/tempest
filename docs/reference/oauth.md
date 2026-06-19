---
title: OAuth Support
updated: 2026-06-19
---

This page compares OAuth behavior across the reference PDS implementations and
Tempest. It covers provider behavior, not general OAuth theory.

## Shared Shape

The implementations use the AT Protocol OAuth profile. Generic OAuth clients
need AT Protocol-specific handling for client metadata, PAR, PKCE, and DPoP. A
client is a public metadata document identified by its `client_id`. The server
treats that document as the registration record. Redirect URIs, allowed scopes,
application type, token endpoint authentication, and DPoP binding come from
that document.

The flow starts with discovery. A client reads the PDS protected-resource and
authorization-server metadata, then sends a pushed authorization request. The
PAR request carries the client ID, redirect URI, scope, S256 PKCE challenge,
optional state, optional prompt hints, and DPoP key binding. The server stores
that request and gives the client a `request_uri`. The browser authorization
screen works from that `request_uri`; the token endpoint later checks the code
against the same stored request.

The token exchange repeats the request's security material. The client sends
`grant_type=authorization_code`, the code, the original `redirect_uri`, the
`client_id`, the PKCE verifier, and a DPoP proof from the same key family used
for the request. Refresh sends the refresh token, `client_id`, matching client
authentication, and a DPoP proof. If the server sends a DPoP nonce challenge,
the client retries with that nonce.

## Implementation Comparison

### Client Registration

Cocoon, Tranquil, ZDS, and Tempest fetch and validate the `client_id` document.
The difference is coverage. Tempest validates the public-client path; the other
implementations also cover more redirect forms, scope families, and private-key
client authentication.

Cocoon validates the broadest metadata shape. It rejects unsupported metadata
fields, unsafe redirect URI forms, local hostnames for ordinary web clients,
implicit grant, and clients that do not opt into DPoP-bound access tokens. It
also has a special `http://localhost` virtual metadata path for development
clients.

Tranquil validates the fields needed for the flow: registered redirect URIs,
`code` response type, `authorization_code` grant type, compatible client
authentication, and redirect URI format. It allows synthesized metadata for
loopback development clients. Non-local clients must use HTTPS.

ZDS fetches client metadata during PAR. It checks the submitted redirect URI
against `redirect_uris` and checks requested scopes against the scope list in
client metadata. Tempest now does the same for HTTPS public clients using
`token_endpoint_auth_method: "none"` and `dpop_bound_access_tokens: true`.

### Client Authentication

Cocoon, Tranquil, ZDS, and Tempest support public clients with
`token_endpoint_auth_method: "none"` and private-key clients with
`private_key_jwt`. Tempest's private-key path follows the AT Protocol OAuth
profile: ES256 assertions, inline `jwks` or HTTPS `jwks_uri`, replay-resistant
`jti` values, and key binding across PAR, token exchange, and refresh.

ZDS spells out the private-key JWT checks in a small code path. The assertion's
issuer and subject must equal the client ID. The audience must equal the server
public URL. Timing claims must be fresh, a `jti` must be present, and the
signature must verify against the client JWKS. Cocoon and Tranquil also fetch or
use client JWKS for private-key clients.

See [`oauth-private-key-jwt`](./oauth-private-key-jwt.md) for Tempest's exact
metadata, assertion, replay, and key-binding rules.

### PAR and PKCE

All four local provider implementations store pushed authorization requests and
make the authorization and token steps refer back to the stored request.
Tranquil, ZDS, and Tempest require S256 PKCE at PAR and verify the PKCE verifier
during token exchange. Cocoon stores and verifies PKCE when a challenge is
present; its code path also accepts `plain`, so its challenge-method policy is
looser.

### DPoP

Cocoon verifies DPoP during PAR, fills or checks `dpop_jkt`, and checks the
binding again during token and refresh. Tranquil accepts DPoP proofs in the
token endpoint path and models DPoP-bound clients in metadata. ZDS advertises
DPoP and returns DPoP token responses. Tempest verifies DPoP at PAR, token
exchange, and refresh.

Tempest's DPoP verifier checks the protected header, embedded JWK signature,
`htm`, `htu`, `iat`, `jti`, and a single-use nonce. Token exchange and refresh
must use the thumbprint saved at PAR.

### Scopes

Cocoon requires the base `atproto` scope and checks for duplicate scopes, but
leaves some unsupported-scope checks as future work. Tranquil and ZDS parse
transition and granular scopes, reject unknown scopes, compare requested scopes
against client metadata, and reject requests that mix transition scopes with
granular scopes.

Tempest uses a smaller allow-list: `atproto`, transition scopes, `blob:*/*`,
`rpc:*`, and `rpc:<nsid>` forms. It now also compares requested scopes to the
client metadata scope registration when the metadata declares one.

### Authorization UI

Cocoon's local OAuth code covers provider mechanics and token issuance. Tranquil
has the broadest browser flow: login, consent, two-factor, passkeys, account
selection, delegation, and registration. ZDS includes a compact authorization
page with password and passkey paths. Tempest has a minimal HTML authorization
page that authenticates by handle, email, or DID and approves the submitted
scope. It does not have a separate consent model, account chooser, passkey OAuth
flow, or prompt handling.

### Token Lifecycle

Cocoon, Tranquil, ZDS, and Tempest issue access and refresh tokens and support
refresh. ZDS and Tranquil expose introspection and revocation. Tempest exposes
both revocation and token introspection.

Tempest stores token material as hashes, rotates refresh tokens, rejects reused
or revoked refresh rows, and signs access tokens as Phoenix tokens backed by
database rows. Those controls cover the narrow flow Tempest implements. They do
not replace client metadata validation.

## Reference Notes

### Official Reference PDS

Remote: https://github.com/bluesky-social/pds

The local `official_reference_pds` checkout is a distribution wrapper around
the `@atproto/pds` package, not an expanded implementation. Its service
entrypoint reads environment, builds `@atproto/pds` config and secrets, starts
`PDS.create(...)`, and exposes a small `/tls-check` helper. The local files do
not contain the provider implementation, but the lockfile shows the package uses
`@atproto/oauth-provider`, `@atproto/oauth-provider-api`,
`@atproto/oauth-provider-ui`, `@atproto/oauth-scopes`, and
`@atproto/oauth-types`.

The local tree is not directly comparable at the same level as the other
references. Its OAuth behavior comes from upstream package dependencies, while
Cocoon, Tranquil, ZDS, and Tempest expose provider code in the local reference
tree.

### Cocoon

Remote: https://github.com/haileyok/cocoon

Cocoon's OAuth code is centered on explicit client metadata validation. Its
provider fetches the metadata document from `client_id`, caches metadata and
JWKS, and has a special virtual metadata path for `http://localhost`
development clients.

A regular Cocoon client needs a metadata document whose `client_id` matches the
URL used by the request. It must register at least one redirect URI, support the
`code` response type, support the `authorization_code` grant, include `atproto`
in its scope string, and set `dpop_bound_access_tokens: true`. Public clients
can use `token_endpoint_auth_method: "none"`. Clients using
`private_key_jwt` need either inline `jwks` or a `jwks_uri`, plus a signing
algorithm.

Cocoon rejects unsupported metadata fields, local hostnames for normal web
metadata, implicit grant, and unregistered or unsafe redirect URI shapes. PAR
verifies the DPoP proof and stores the DPoP key thumbprint. The token endpoint
then checks the code, redirect URI, PKCE verifier, client authentication, and
DPoP binding before issuing tokens.

### Tranquil

Remote: https://tangled.org/tranquil.farm/tranquil-pds

Tranquil splits client metadata handling into `tranquil-oauth` and server
routes into `tranquil-oauth-server`. Its metadata advertises PAR, authorization
code, refresh token, S256 PKCE, response modes `query` and `fragment`, DPoP,
revocation, introspection, prompt values, dynamic client metadata documents,
and client authentication methods `none` and `private_key_jwt`.

Tranquil has browser-facing login, consent, two-factor, passkey,
account-selection, and registration routes around the OAuth core. The OAuth
layer still keeps the server-side constraints sharp: client metadata must
contain registered redirect URIs, the `code` response type, the
`authorization_code` grant, and a compatible authentication method. Loopback
development clients get a synthesized metadata path; normal non-local clients
must use HTTPS. Redirect URIs may not contain fragments, and HTTP redirect URIs
are confined to local loopback hosts.

Tranquil's PAR endpoint accepts JSON or form requests. It requires
`response_type=code`, a `code_challenge`, S256 PKCE, a registered redirect URI,
valid client authentication, and a scope string it can parse. If the client
metadata declares scopes, the requested scope must fit inside that registration.
Tranquil also enforces a scope-family rule: transition scopes and granular
scopes cannot be mixed in one request. Token exchange verifies the stored
authorization request and PKCE verifier; refresh uses stored token state and
client authentication; introspection and revocation are first-class routes.

### ZDS

Remote: https://tangled.org/zat.dev/zds

ZDS keeps most OAuth provider behavior in one Zig module. Its metadata
advertises PAR, authorization code, refresh token, S256 PKCE, DPoP, revocation,
introspection, prompt values, client metadata documents, and both public and
`private_key_jwt` client authentication.

During PAR, ZDS fetches the client metadata JSON from `client_id`, requires
`response_type=code`, checks the redirect URI against the client's
`redirect_uris`, requires S256 PKCE, validates response mode and prompt, checks
requested scopes against the client metadata scope list, and stores the request.
It supports granular scope families such as `repo:*`, `blob:*/*`, `rpc:*`,
`account:*`, `identity:*`, and `include:*`, while rejecting unsupported scopes
and rejecting transition-granular mixtures.

ZDS includes the most direct local `private_key_jwt` path. The client assertion
must use the `client_id` as both issuer and subject, use the server public URL
as audience, include fresh timing claims and a `jti`, and verify against the
client JWKS. Token exchange consumes the authorization code, checks `client_id`,
redirect URI, PKCE, and client authentication, then returns a DPoP token
response. Refresh revokes the old refresh token when it issues the next one.

### Tempest

Tempest currently implements the core OAuth flow in `Tempest.OAuth` and
`TempestWeb.OAuthController`. It exposes protected-resource metadata,
authorization-server metadata, `/oauth/jwks`, PAR, browser authorization, token
exchange, refresh, and revocation.

The implementation is narrower than Tranquil or ZDS, but the existing controls
are concrete:

- PAR rows expire
- Authorization codes are single-use
- Refresh tokens rotate
- Token material is stored as hashes
- DPoP nonces are consumed

Tempest requires `client_id`, `redirect_uri`, `scope`, `code_challenge`, and
`code_challenge_method=S256` at PAR. It requires a DPoP proof whose `htu`
matches `/oauth/par`, consumes a Tempest-issued DPoP nonce, stores the proof
thumbprint as `dpop_jkt`, and then fetches the client metadata document from
`client_id`. The metadata must match the `client_id`, register the submitted
redirect URI, include `code` and `authorization_code`, use public client
authentication, and opt into DPoP-bound access tokens. Tempest validates the
requested scope against its local allow-list and, when metadata declares a
scope string, against the client's registered scopes. PAR rows expire after ten
minutes.

The authorization page authenticates a local account by handle, email, or DID,
marks the PAR row used, creates a short-lived authorization code, and redirects
back with `code` and optional `state`. Token exchange requires `code`,
`client_id`, `redirect_uri`, `code_verifier`, matching client and redirect URI,
S256 PKCE verification, and a DPoP proof bound to the same `dpop_jkt`. Refresh
requires the same client ID, rotates refresh tokens, and rejects already rotated
or revoked rows. Access tokens are Phoenix tokens backed by database token rows,
with hashed access and refresh token storage.

Tempest does not support private-use redirect schemes. Loopback development
client metadata and token introspection are supported for the local OAuth flow.

Tempest can issue DPoP-bound OAuth tokens through PAR and PKCE, but it still
implements a smaller client model than Cocoon, Tranquil, or ZDS.

## Client Compatibility

For client development, implement the strict profile even when a server accepts
less.

- Publish a complete HTTPS metadata document.
- Register every redirect URI and every scope you may request.
- Use PAR, S256 PKCE, DPoP, and refresh rotation correctly.
- Repeat the redirect URI during token exchange.
- Do not mix transition scopes with granular scopes when targeting Tranquil or
  ZDS.

A client built to that shape should interoperate with the reference
implementations and with Tempest's current narrower flow.
