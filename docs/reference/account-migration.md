---
title: Account Migration
updated: 2026-06-13
---

This page describes the migration path Tempest supports today and the identity
work still required for production `did:plc` account moves.

Account migration has two separate parts:

1. Move repository and blob data to Tempest.
2. Move identity authority so the DID document's `#atproto_pds` service points
   at Tempest.

Tempest implements the repository and lifecycle side: existing-DID account
creation with service auth, inactive imported accounts, CAR import, missing-blob
checks, activation/deactivation, and account deletion. Activation is intentionally
gated on identity correctness. Tempest must not publicly serve a migrated account
until the DID document points at this PDS.

## Current Support

Supported now:

- Create an inactive account for an existing DID when `createAccount` receives a
  valid service-auth token for `com.atproto.server.createAccount`.
- Import a repository CAR through `com.atproto.repo.importRepo`.
- Keep imported accounts inactive until activation.
- Report repository, record, blob, missing-blob, and `migrationReady` state
  through `com.atproto.server.checkAccountStatus`.
- List missing blobs through `com.atproto.repo.listMissingBlobs`.
- Activate only after the local DID document exposes `#atproto_pds` for
  `TEMPEST_PUBLIC_URL`.
- Suppress public repo, record, blob, and sync reads for inactive accounts.

### To-Do

- Full `did:plc` migration still needs black-box migration-out coverage, but the
  public PLC identity endpoints are registered and locally tested against the PLC
  client boundary.

Self-controlled `did:web` accounts remain the simplest bring-your-own identity
path because the operator can update the DID document directly.

## Migration-In Flow

The Python CLI mirrors the manual curl flow below. It reads configuration from
environment variables, writes artifacts into `.sandbox/` by default, and defaults
to the full migration-in sequence:

```bash
export OLD_PDS="https://jellybaby.us-east.host.bsky.network"
export OLD_AUTH_PDS="$OLD_PDS"
export OLD_LOGIN_PDS="$OLD_AUTH_PDS"
export HANDLE="tempestpds.bsky.social"
export DID="did:plc:oga6ppys7zwxlheuqmcm7dac"
export TEMPEST="https://tempest.desertthunder.dev"
export TEMPEST_SERVICE_DID="did:web:tempest.desertthunder.dev"
export EMAIL="operator@example.com"
export OLD_IDENTIFIER="$HANDLE"
read -rs OLD_PASSWORD
export OLD_PASSWORD
read -rs TEMPEST_PASSWORD
export TEMPEST_PASSWORD

# Optional, only if the source PDS requires an auth-factor token/code during
# createSession.
read -rs OLD_AUTH_FACTOR_TOKEN
export OLD_AUTH_FACTOR_TOKEN

uv run --project scripts tempest
```

Use `read -rs` or single quotes for passwords. Unquoted shell assignments can
expand characters like `$`, so a password containing `$N` will not be passed
literally.

Run individual steps when resuming or inspecting a failure:

```bash
uv run --project scripts tempest login-source
uv run --project scripts tempest service-auth
uv run --project scripts tempest source-session-status
uv run --project scripts tempest export-car
uv run --project scripts tempest list-source-blobs
uv run --project scripts tempest download-source-blobs
uv run --project scripts tempest create-account
uv run --project scripts tempest refresh-session
uv run --project scripts tempest import-repo
uv run --project scripts tempest status
uv run --project scripts tempest missing-blobs
uv run --project scripts tempest upload-missing-blobs
uv run --project scripts tempest plc-recommended
uv run --project scripts tempest plc-request-token
uv run --project scripts tempest plc-sign
uv run --project scripts tempest plc-submit
uv run --project scripts tempest activate
```

The same project also exposes the admin-token Argon2 helper as
`tempest argon`, with `tempest ar` and `tempest arg2` aliases.

From the source PDS, export the account repository:

```bash
curl "$OLD_PDS/xrpc/com.atproto.sync.getRepo?did=$DID" -o repo.car
```

Ask the source PDS for service auth scoped to account creation on Tempest:

```bash
TEMPEST_SERVICE_DID=did:web:tempest.example.com

curl -H "Authorization: Bearer $OLD_ACCESS" \
  "$OLD_PDS/xrpc/com.atproto.server.getServiceAuth?aud=$TEMPEST_SERVICE_DID&lxm=com.atproto.server.createAccount"
```

`aud` is the target service DID, not the HTTPS service endpoint. The HTTPS
endpoint still belongs in the public DID document's `#atproto_pds`
`serviceEndpoint`.

Create the account on Tempest with the existing DID:

```bash
curl -X POST "$TEMPEST/xrpc/com.atproto.server.createAccount" \
  -H "Content-Type: application/json" \
  -d '{
    "did": "'"$DID"'",
    "handle": "'"$HANDLE"'",
    "email": "'"$EMAIL"'",
    "password": "'"$PASSWORD"'",
    "serviceAuth": "'"$SERVICE_AUTH"'"
  }'
```

The response should include:

```json
{ "did": "did:example:...", "active": false, "status": "deactivated" }
```

Import the CAR:

```bash
curl -X POST "$TEMPEST/xrpc/com.atproto.repo.importRepo" \
  -H "Authorization: Bearer $TEMPEST_ACCESS" \
  -H "Content-Type: application/vnd.ipld.car" \
  --data-binary @repo.car
```

Check for missing blobs:

```bash
curl -H "Authorization: Bearer $TEMPEST_ACCESS" \
  "$TEMPEST/xrpc/com.atproto.repo.listMissingBlobs"
```

Upload any missing blobs, then check readiness:

```bash
curl -H "Authorization: Bearer $TEMPEST_ACCESS" \
  "$TEMPEST/xrpc/com.atproto.server.checkAccountStatus"
```

`migrationReady` should be `true` and `missingBlobCount` should be `0` before
activation.

Update identity so the account DID document points `#atproto_pds` at
`TEMPEST_PUBLIC_URL`. For `did:web`, update the hosted DID document. For
`did:plc`, use `getRecommendedDidCredentials`, `requestPlcOperationSignature`,
`signPlcOperation`, and `submitPlcOperation` to build, sign, and submit the PLC
operation through Tempest's PLC client boundary.

For the current `did:plc` migration, use the CLI helpers:

```bash
uv run --project scripts tempest refresh-session
uv run --project scripts tempest plc-recommended
uv run --project scripts tempest login-source
uv run --project scripts tempest plc-request-token
```

`plc-request-token` writes `.sandbox/plc_token.json` when the source PDS returns
a token directly. Some PDS implementations email a one-time code instead; in
that case export it before signing:

```bash
export PLC_TOKEN="code-from-email"
uv run --project scripts tempest plc-sign
```

If `plc-request-token` returns `Bad token scope`, refresh the source session with
the main account password rather than an app password. If the source PDS requires
an auth-factor token/code for high-risk account operations, set
`OLD_AUTH_FACTOR_TOKEN` and rerun `login-source`, then rerun `plc-request-token`.
If handle login returns `Invalid identifier or password`, set `OLD_IDENTIFIER`
to the account email address and retry `login-source`.

If the account's repository host rejects main-password login even though the
credentials work in Bluesky, keep `OLD_PDS` pointed at the repository host for
CAR/blob export, keep `OLD_AUTH_PDS` pointed at the old PDS for authenticated
PLC operations, and set `OLD_LOGIN_PDS` to the Bluesky entryway:

```bash
export OLD_PDS="https://jellybaby.us-east.host.bsky.network"
export OLD_AUTH_PDS="$OLD_PDS"
export OLD_LOGIN_PDS="https://bsky.social"
uv run --project scripts tempest login-source
uv run --project scripts tempest plc-request-token
```

If login succeeds but `plc-request-token` still returns `Bad token scope`, check
that the saved token works for ordinary old-PDS auth:

```bash
uv run --project scripts tempest source-session-status
```

If `source-session-status` succeeds while `plc-request-token` fails, the source
session is valid but the old PDS is refusing that session scope for PLC signing.

Before submitting, inspect the signed operation. The PDS service endpoint must
be Tempest:

```bash
jq '.operation.services.atproto_pds.endpoint' .sandbox/plc_signed_operation.json
```

Then submit the signed PLC operation through Tempest:

```bash
uv run --project scripts tempest plc-submit
curl -fsS "https://plc.directory/$DID" | jq '.service'
```

The resolved DID document should include `#atproto_pds` with
`serviceEndpoint` equal to `https://tempest.desertthunder.dev` for the current
deployment.

Activate the account:

```bash
uv run --project scripts tempest refresh-session
uv run --project scripts tempest activate
uv run --project scripts tempest status
```

The equivalent curl call is:

```bash
curl -X POST "$TEMPEST/xrpc/com.atproto.server.activateAccount" \
  -H "Authorization: Bearer $TEMPEST_ACCESS" \
  -H "Content-Type: application/json" \
  -d '{}'
```

After activation, public repo, record, blob, and sync reads become available.

## Failure Behavior

Tempest fails closed during migration:

- Missing or invalid service auth prevents existing-DID account creation.
- Invalid CAR data is rejected without replacing the existing repository.
- CAR commits for a different DID are rejected.
- Invalid commit signatures are rejected.
- Missing referenced blocks are rejected.
- Missing referenced blobs keep `migrationReady=false`.
- Activation fails when the DID document does not point at Tempest.

## PLC Operation Flow

Production `did:plc` migration uses the public identity operation flow, not only
repository import:

- `com.atproto.identity.getRecommendedDidCredentials` must return the Tempest PDS
  service endpoint, repository signing key, handle, and recommended rotation
  keys.
- `com.atproto.identity.requestPlcOperationSignature` must create an auditable
  strong-reauth challenge for PLC-sensitive operations.
- `com.atproto.identity.signPlcOperation` must reject operations that remove
  recoverability or point `#atproto_pds` away from the intended service.
- `com.atproto.identity.submitPlcOperation` must submit through the PLC client,
  preserve migration event ordering, and record success or failure.

These endpoints deny app passwords and ordinary OAuth tokens unless a future spec
defines a high-assurance delegated scope. Configure `TEMPEST_PLC_ROTATION_KEY`
with private rotation-key material; optionally configure `TEMPEST_PLC_RECOVERY_KEY`
for an operator recovery key. Tempest derives public `did:key` rotation keys from
that material and does not reuse repository signing keys as PLC rotation keys.

The vendored lexicon files for this flow live in `priv/lexicons/official`:

- `com/atproto/identity/requestPlcOperationSignature.json`: no input body; asks
  the old PDS to email a PLC operation code.
- `com/atproto/identity/signPlcOperation.json`: takes the emailed `token` plus
  `rotationKeys`, `alsoKnownAs`, `verificationMethods`, and `services`.
- `com/atproto/server/createSession.json`: takes `identifier`, `password`, and
  optional `authFactorToken`.

## Verification

Local lifecycle coverage:

```bash
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  test/smoke/migration-lifecycle.hurl
```

Compatibility tracking:

- [Migration and Account Lifecycle](./migration-lifecycle.md)
- [PDS Compatibility Matrix](./pds-compatibility.md)
- [CAR and DRISL](./car-drisl.md)
- [Identity Troubleshooting](./identity-troubleshooting.md)
