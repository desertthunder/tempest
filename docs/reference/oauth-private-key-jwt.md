---
title: OAuth private_key_jwt Concepts
updated: 2026-06-19
---

A private key JWT is a way for an OAuth client to prove its identity with a
public/private key pair instead of a shared client secret.

The key idea is that the client publishes a public key, keeps the private key
secret, and signs a short-lived JWT when it talks to the authorization server.
The server verifies the signature with the published public key. If the claims
inside the JWT also match the OAuth request, the server knows the request came
from the same client that controls the private key.

This is client authentication. In Tempest's OAuth flow, the client still uses
PAR, PKCE, DPoP, authorization codes, and refresh tokens. `private_key_jwt`
answers only one question:

> "Is this confidential client really the client identified by this `client_id`?"

## Why It Exists

Public OAuth clients cannot keep secrets. Native apps, browser apps, and many
developer tools can send a `client_id`, but that ID is public information. They
authenticate the flow with other controls such as redirect URI registration,
PKCE, and DPoP.

Confidential clients run somewhere that can protect private key material, such
as a backend service. Those clients can use `private_key_jwt` to authenticate
the client itself. This gives the authorization server stronger confidence that
token exchange and refresh requests are coming from the same deployed client,
not only from someone who copied a public `client_id`.

## The Trust Model

There are three moving parts:

1. The `client_id` identifies the client's metadata document.
2. The metadata document publishes one or more public keys in `jwks` or
   `jwks_uri`.
3. The client signs a JWT assertion with the matching private key.

The authorization server does not fetch the client's private key and does not
need a pre-registered client secret. It only needs the public key and enough
claims in the signed JWT to know what the signature is meant to authenticate.

This model is useful for AT Protocol because clients are registered through
client metadata documents rather than through a central registration database.
The metadata document becomes both the registration record and the place where
confidential clients publish their authentication keys.

## The Assertion

The assertion is a signed JWT sent in the OAuth request body:

```text
client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer
client_assertion=<signed JWT>
```

The JWT has two important parts:

- The protected header names the signing algorithm and key, usually with `alg`
  and `kid`.
- The claims say who issued the assertion, who it authenticates, who may accept
  it, when it expires, and which unique assertion ID prevents replay.

For `private_key_jwt`, `iss` and `sub` both identify the OAuth client. The
`aud` claim identifies the authorization server. `exp` keeps the assertion
short-lived. `jti` gives the server a value it can remember so the same
assertion cannot be reused.

## How The Server Thinks About It

The server's validation is a chain of defensive questions:

1. Is this client metadata document valid, and does it say the client uses
   `private_key_jwt`?
2. Does the metadata publish exactly the kind of public key this server
   supports?
3. Does the assertion header point at one of those keys?
4. Does the signature verify with that public key?
5. Do `iss` and `sub` equal the `client_id`?
6. Is the `aud` value this authorization server, not some other server?
7. Are the timing claims fresh?
8. Has this `jti` already been used?
9. For an existing session, is the client still using the same key it used when
   the session began?

Any "no" answer means the client has not authenticated.

## Replay Protection

A signed assertion is a bearer object for as long as it is valid. If an attacker
can copy it, they may be able to replay it unless the server remembers that it
has already seen the assertion's `jti`.

That is why `jti` matters. It is not just an identifier for logging. It is the
server's handle for single-use assertion enforcement. The replay cache only
needs to last until the assertion expires.

## Key Binding

Confidential OAuth sessions should stay bound to the key that authenticated the
session at the start. Without that rule, a client could begin a session with one
key and later refresh with another key, which makes compromise and rotation
semantics harder to reason about.

AT Protocol OAuth makes this explicit. The authorization server binds the active
session to the assertion key's `kid`, signing algorithm, and JWK thumbprint. On
token exchange and refresh, the server checks that the same key binding is still
used and that the key is still present in the client's metadata.

This also gives key removal real force. If a private key is compromised, the
client can remove the public key from metadata. Authorization servers that
re-fetch metadata can then reject future refreshes tied to that key.

## Key Rotation

Safe rotation usually has three phases:

1. Publish the new public key while keeping the old key available.
2. Start new sessions with the new private key.
3. Remove the old public key only after sessions bound to it have expired or
   been revoked.

Removing the old key too early can break legitimate refreshes. Keeping it too
long extends the usefulness of a leaked private key. The right window depends on
the server's session lifetime policy.

## Standards Shape

The relevant standards layer the requirements:

- RFC 7523 defines the transport parameters. The request includes
  `client_assertion_type` with value
  `urn:ietf:params:oauth:client-assertion-type:jwt-bearer`, and a single JWT in
  `client_assertion`.
- OpenID Connect Core describes `private_key_jwt` as a client that signs this
  assertion with a registered public key. Its required claim set includes
  `iss`, `sub`, `aud`, `jti`, and `exp`; `iat` is optional there.
- The AT Protocol OAuth profile tightens the profile for PDS use. Confidential
  clients publish public keys in either inline `jwks` or HTTPS `jwks_uri`, use
  `token_endpoint_auth_method: "private_key_jwt"`, support `ES256`, include
  `iat` and a replay-resistant `jti`, set `aud` to the authorization server
  issuer, and keep the same authentication key for the active session.

Tempest follows the AT Protocol profile where it is stricter than generic OAuth
or OIDC.

## How Tempest Applies It

Tempest supports `private_key_jwt` for confidential clients on PAR, token
exchange, and refresh.

Tempest currently accepts only `ES256` client assertions. A confidential client
metadata document must set `token_endpoint_auth_method: "private_key_jwt"` and
publish public P-256 keys through either inline `jwks` or HTTPS `jwks_uri`.

For example:

```json
{
  "client_id": "https://client.example.com/oauth/client-metadata.json",
  "redirect_uris": ["https://client.example.com/callback"],
  "grant_types": ["authorization_code", "refresh_token"],
  "response_types": ["code"],
  "scope": "atproto",
  "token_endpoint_auth_method": "private_key_jwt",
  "token_endpoint_auth_signing_alg": "ES256",
  "dpop_bound_access_tokens": true,
  "jwks": {
    "keys": [{ "kid": "client-key-2026-06", "kty": "EC", "crv": "P-256", "alg": "ES256", "x": "...", "y": "..." }]
  }
}
```

Instead of inline `jwks`, the document may include `jwks_uri`. Tempest fetches
that URI through the same hardened external metadata boundary used for client
metadata.

Tempest rejects confidential metadata when:

- both `jwks` and `jwks_uri` are present
- neither key source is present
- a key lacks `kid`
- the key is not an `EC` `P-256` public key
- the key contains private material such as `d`
- `token_endpoint_auth_signing_alg` is anything other than `ES256`

Tempest stores a hash of each accepted `(client_id, jti)` pair until the
assertion expires, and it records the PAR assertion key binding on the
authorization code and refresh-token family. Token exchange and refresh must use
that same binding.

## What To Remember

- `private_key_jwt` authenticates the client, not the user.
- The public key lives in client metadata; the private key never leaves the
  client.
- The assertion is short-lived and single-use.
- `aud` prevents a JWT made for one authorization server from being accepted by
  another.
- `jti` prevents replay.
- Key binding keeps a confidential-client session tied to the key that started
  it.

Expired assertion replay rows are harmless but can accumulate. A cleanup task
for expired `oauth_client_assertions` rows is a reasonable follow-up if
confidential-client traffic becomes high.
