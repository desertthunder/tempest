---
title: Architecture
updated: 2026-05-08
---

# Architecture

Tempest should stay a Phoenix application while the PDS shape is still forming. Use internal contexts first, then split into an umbrella only if compile time, release packaging, or ownership boundaries justify it.

## Target Runtime

```text
TempestWeb
  /xrpc HTTP routes
  WebSocket firehose endpoint
  health and admin routes

Tempest.Xrpc
  method registry
  request/response validation
  error mapping
  auth plugs

Tempest.Accounts
  accounts, sessions, app passwords, account status, recovery

Tempest.Identity
  DID documents, handle verification, PLC calls, signing keys

Tempest.Authz
  OAuth provider, permission engine, delegated access, MFA

Tempest.RepoCore
  AT URIs, NSIDs, TIDs, CIDs, DRISL CBOR, MST, commits, CAR

Tempest.Records
  createRecord, putRecord, deleteRecord, getRecord, listRecords

Tempest.Blobs
  upload, metadata, local/S3 storage, references, GC

Tempest.Sync
  sequencer, repo events, backfill, firehose fanout

Tempest.Admin
  repair, backup, restore, verification tasks

TempestWeb.AccountUI
  account management, OAuth consent, repo browser, security settings
```

## Protocol Facts

- XRPC endpoints are top-level paths under `/xrpc/<nsid>`.
- A PDS is the authoritative host for the repositories it serves; the account DID document declares that location.
- Repository data is public, content-addressed, signed, and exported as CAR.
- Blobs are content-addressed but managed in the context of a DID.
- Firehose streams include repository, identity, account, and sync events for accounts hosted by this server.

## Project Choices

- SQLite is the default storage target.
- The local filesystem is the default blob store.
- Repo-core correctness has priority over broad endpoint coverage.
- OAuth is a later milestone, but its data model must be anticipated by sessions, app passwords, and delegated access.
- A complete self-hosted PDS needs account migration, lifecycle, recovery, and operator UX before production-ready claims.
- Rustler is allowed for repo-core if Elixir libraries cannot meet byte-level requirements.

## Write Path

```text
HTTP request
  -> XRPC method lookup
  -> Lexicon input validation
  -> auth
  -> context operation
  -> SQLite transaction
  -> repo commit
  -> sequencer event
  -> response rendering
```

## Adversarial Checks

- A controller must not build commits directly.
- A repo mutation must not be visible without a matching sequencer event.
- DID, handle, NSID, AT URI, and rkey parsers must reject invalid syntax before storage.
- Every externally fetched URL must pass SSRF checks.
- Every feature must have a black-box HTTP test before it is called done.
- OAuth, app passwords, delegated access, and admin tokens must share one auditable permission boundary.
- Import, restore, and migration flows must fail closed and must never activate partially verified account state.

## HTTP Verification

```bash
curl -fsS http://localhost:4000/xrpc/_health
http GET :4000/xrpc/com.atproto.server.describeServer
```

Expected once Milestone 01 is complete:

- `_health` returns JSON.
- `describeServer` returns JSON with the Tempest PDS service metadata.

## Sources

- <https://atproto.com/specs/xrpc>
- <https://atproto.com/specs/repository>
- <https://atproto.com/specs/sync>
- <https://github.com/bluesky-social/pds>
