---
title: Tokens
updated: 2026-06-13
---

This page covers operational token handling for Tempest deployment and account
migration work. Keep raw tokens out of Git, logs, tickets, screenshots, and chat.
Use `.sandbox/` or a local password manager for temporary working files.

## Token Types

Common tokens in deployment and migration:

- `ADMIN_TOKEN`: raw operator token for Tempest admin routes. Railway stores only
  `TEMPEST_ADMIN_TOKEN_HASH`.
- account `accessJwt`: short-lived bearer token returned by
  `com.atproto.server.createSession`.
- account `refreshJwt`: refresh token returned by session creation and refresh.
- `serviceAuth`: scoped proof from one PDS to another, returned by
  `com.atproto.server.getServiceAuth`.
- PLC operation token/code: short-lived one-time authorization for
  `com.atproto.identity.signPlcOperation`, requested from the current PDS during
  `did:plc` identity migration.
- app password: Bluesky-compatible account password substitute for client and
  bot login. Prefer this over the main account password for migration commands
  when the source PDS accepts it.

## Source Account Access Token

To migrate an account from its current PDS, first create a normal session on the
current authoritative PDS. For the current `tempestpds.bsky.social` migration
example:

```bash
export OLD_PDS="https://jellybaby.us-east.host.bsky.network"
export HANDLE="tempestpds.bsky.social"
export TEMPEST="https://tempest.desertthunder.dev"
export TEMPEST_SERVICE_DID="did:web:tempest.desertthunder.dev"

read -s OLD_PASSWORD
```

Use the main account password for PLC operation signing. App passwords can be
useful for ordinary source-PDS access, but they may produce a session that cannot
request a PLC operation signature.

If the source PDS asks for an auth-factor token/code during login, pass it to
the CLI as `OLD_AUTH_FACTOR_TOKEN`:

```bash
read -s OLD_AUTH_FACTOR_TOKEN
export OLD_AUTH_FACTOR_TOKEN
```

The migration CLI reads the same environment variables as the curl examples and
writes the same artifacts:

```bash
UV_CACHE_DIR=.sandbox/uv-cache uv run --project scripts tempest login-source
```

Use the account password or a Bluesky app password:

```bash
curl -fsS -X POST "$OLD_PDS/xrpc/com.atproto.server.createSession" \
  -H "Content-Type: application/json" \
  --data "$(jq -n \
    --arg identifier "$HANDLE" \
    --arg password "$OLD_PASSWORD" \
    '{identifier: $identifier, password: $password}')" \
  > .sandbox/old_session.json
```

Extract the source access token:

```bash
export OLD_ACCESS="$(jq -r .accessJwt .sandbox/old_session.json)"
```

Check that extraction worked without printing the token:

```bash
jq '{did, handle, has_access: (.accessJwt != null), has_refresh: (.refreshJwt != null)}' \
  .sandbox/old_session.json
```

## Service Auth for Migration

Ask the old PDS for service auth scoped to account creation on Tempest:

```bash
UV_CACHE_DIR=.sandbox/uv-cache uv run --project scripts tempest service-auth
```

The equivalent curl call is:

```bash
curl -fsS -G "$OLD_PDS/xrpc/com.atproto.server.getServiceAuth" \
  -H "Authorization: Bearer $OLD_ACCESS" \
  --data-urlencode "aud=$TEMPEST_SERVICE_DID" \
  --data-urlencode "lxm=com.atproto.server.createAccount" \
  > .sandbox/service_auth_create_account.json
```

`aud` must be a DID. Do not use `https://tempest.desertthunder.dev` as the
`getServiceAuth` audience; current PDS implementations reject URL audiences with
`InvalidRequest`.

Check that a token exists without printing it:

```bash
jq '{has_token: (.token != null)}' .sandbox/service_auth_create_account.json
```

Export the token for the next Tempest request:

```bash
export SERVICE_AUTH="$(jq -r .token .sandbox/service_auth_create_account.json)"
```

Use that value as `serviceAuth` when calling Tempest
`com.atproto.server.createAccount` with an existing DID. The service-auth token
must have:

- issuer and subject equal to the account DID;
- audience equal to the target service DID, such as
  `did:web:tempest.desertthunder.dev`;
- method (`lxm`) equal to `com.atproto.server.createAccount`.

## Admin Token Hash

Generate `TEMPEST_ADMIN_TOKEN_HASH` through the same uv project:

```bash
UV_CACHE_DIR=.sandbox/uv-cache uv run --project scripts tempest argon
```

The `ar` and `arg2` aliases run the same helper:

```bash
UV_CACHE_DIR=.sandbox/uv-cache uv run --project scripts tempest ar --only-hash
```

## PLC Operation Token

After repo import and blob upload, the `did:plc` document must be updated so
`#atproto_pds` points at Tempest. The source PDS signs that PLC operation after
issuing a short-lived token or emailing a one-time code:

```bash
UV_CACHE_DIR=.sandbox/uv-cache uv run --project scripts tempest plc-recommended
UV_CACHE_DIR=.sandbox/uv-cache uv run --project scripts tempest plc-request-token
```

If `.sandbox/plc_token.json` contains a `token`, the CLI will read it. If the
source PDS emails a code instead, keep it out of shell history when possible and
export it only for the signing step:

```bash
read -s PLC_TOKEN
export PLC_TOKEN
UV_CACHE_DIR=.sandbox/uv-cache uv run --project scripts tempest plc-sign
```

The signed operation is written to `.sandbox/plc_signed_operation.json`.
Inspect its service endpoint before submitting it:

```bash
jq '.operation.services.atproto_pds.endpoint' .sandbox/plc_signed_operation.json
```

For this deployment the value must be `https://tempest.desertthunder.dev`.

If `plc-request-token` returns `Bad token scope`, the source session is not
authorized for PLC signing. Re-run `login-source` with the main account password
and any required `OLD_AUTH_FACTOR_TOKEN`, then retry `plc-request-token`.

## Safety Notes

- Do not commit `.sandbox/old_session.json`,
  `.sandbox/service_auth_create_account.json`,
  `.sandbox/plc_token.json`, `.sandbox/plc_signed_operation.json`, or shell
  history containing raw tokens.
- Prefer app passwords over the main account password for source-PDS session
  creation.
- Revoke or rotate the app password after migration.
- Treat `serviceAuth` as short-lived migration material. Regenerate it if the
  migration attempt is delayed.
- Treat PLC operation tokens/codes as single-use, short-lived migration
  material. Regenerate the token/code if signing fails or the token expires.
- Treat Tempest `accessJwt` as short-lived. If migration commands return
  `Bearer token is invalid` or `Bearer token is expired`, refresh the saved
  Tempest session:

  ```bash
  UV_CACHE_DIR=.sandbox/uv-cache uv run --project scripts tempest refresh-session
  ```

- Keep the old PDS account active until Tempest passes repo, blob, firehose,
  crawler, DID, and real-client checks.

## Related Runbooks

- [Account Migration](./account-migration.md)
- [Deployment Guide](./deployment.md)
- [Deployment and Observability](./deployment-observability.md)
- [Security, OAuth, and Delegated Access](./security-oauth.md)
