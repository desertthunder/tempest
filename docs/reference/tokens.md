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

## Safety Notes

- Do not commit `.sandbox/old_session.json`,
  `.sandbox/service_auth_create_account.json`, or shell history containing raw
  tokens.
- Prefer app passwords over the main account password for source-PDS session
  creation.
- Revoke or rotate the app password after migration.
- Treat `serviceAuth` as short-lived migration material. Regenerate it if the
  migration attempt is delayed.
- Keep the old PDS account active until Tempest passes repo, blob, firehose,
  crawler, DID, and real-client checks.

## Related Runbooks

- [Account Migration](./account-migration.md)
- [Deployment Guide](./deployment.md)
- [Deployment and Observability](./deployment-observability.md)
- [Security, OAuth, and Delegated Access](./security-oauth.md)
