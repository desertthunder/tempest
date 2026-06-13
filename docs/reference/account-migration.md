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

Activate the account:

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
- [Identity Troubleshooting](./identity-troubleshooting.md)
