---
title: Migration and Account Lifecycle
updated: 2026-05-31
---

Account migration lets a DID move between PDS hosts without changing the account
identifier. Tempest keeps this flow explicit: an imported account is present in
local storage, but it is not publicly served until activation proves the account
belongs on this PDS.

## Concepts

Atproto account identity is the DID. Handles may change, but clients and relays
follow the DID document's `#atproto_pds` service to find the authoritative PDS.
A migration therefore has two parts:

1. Move repository and blob data to the new PDS.
2. Update identity so the DID document points at the new PDS.

`active=false` means Tempest must not redistribute repo content. Sync repo reads,
record reads, blob reads, and commit events are suppressed while the account is
inactive. Account status and identity metadata may still be visible.

## XRPC Methods

Account lifecycle:

- `com.atproto.server.checkAccountStatus`
- `com.atproto.server.getServiceAuth`
- `com.atproto.server.reserveSigningKey`
- `com.atproto.server.activateAccount`
- `com.atproto.server.deactivateAccount`
- `com.atproto.server.requestAccountDelete`
- `com.atproto.server.deleteAccount`

Migration data:

- `com.atproto.repo.importRepo`
- `com.atproto.repo.listMissingBlobs`

`createAccount` also accepts an existing `did` when accompanied by a valid
service-auth proof for `com.atproto.server.createAccount`.

## Create and import flow

When `createAccount` receives an existing DID, Tempest validates the service-auth
proof and creates the account as:

```text
active=false
status=deactivated
```

The account receives stable signing-key material and an empty repo, but public
sync reads remain disabled. `importRepo` then replaces the repo with the imported
CAR after verification.

The import boundary checks:

- valid CAR container and commit root
- commit block is present and matches its CID
- commit DID matches the authenticated account
- complete MST graph and all referenced record blocks are present
- commit signature verifies against the DID document
- replacement is atomic, so failed imports leave the prior repo intact

Post-import writes use the normal repo write path. Revisions are monotonic: if the
clock would produce a lower or equal TID, Tempest increments from the imported
current revision.

## Blob readiness

`listMissingBlobs` compares blob references indexed from current records with
local blob metadata. It returns referenced CIDs that still need to be uploaded.

`checkAccountStatus` reports repo, record, public blob, and missing blob counts,
plus `migrationReady`. Missing blobs keep `migrationReady=false`.

## Activation and lifecycle events

`activateAccount` verifies local DID-document consistency before changing state.
The DID document must match the account and expose `#atproto_pds` for this
Tempest public URL.

Activation emits events in migration-safe order:

```text
#identity
#account active=true
#commit repo.activate
```

The commit event contains a CAR slice for the latest imported state. After this,
public sync reads and future commit events are enabled.

`deactivateAccount` sets `active=false`, `status=deactivated`, and emits an
account event before public content can be redistributed again. `deleteAccount`
sets `status=deleted`, revokes active sessions, and emits `#account active=false`.

## Recovery notes

A missing or bad service-auth proof fails closed before account creation for an
existing DID. This covers the unavailable-old-PDS path until fuller PLC and
external DID resolution flows are implemented.

Self-controlled `did:web` accounts can be created with service auth and activated
when their local DID document points at this PDS. This is the current tested path
for bring-your-own identity migration.

## Verification

```bash
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  test/smoke/migration-lifecycle.hurl
```

The smoke test covers status, service auth, exported-CAR fixture reads, bad CAR
atomicity, missing blobs, deactivation suppression, activation, and deletion.
