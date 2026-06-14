---
title: Architecture
updated: 2026-06-03
---

Tempest is a Phoenix application that implements AT Protocol PDS behavior through
small contexts: XRPC routing, accounts/auth, identity, repository storage, blobs,
sync, and operator tooling.

## Concepts

A PDS hosts user repositories. Each account has a DID, a mutable handle, a signed
repository, and blob data referenced by records. Other services discover where a
repo lives through the account's DID document and then read repo data through
XRPC sync endpoints or the firehose.

XRPC is the HTTP RPC layer. Repository data is content-addressed and exported as
CAR. Firehose events announce changes after they are durably sequenced.

Key protocol objects:

- DID: stable decentralized identifier for an account.
- Handle: mutable human-readable name that resolves to a DID.
- Repo: signed personal data store for one DID.
- MST: Merkle Search Tree used to represent current repo records.
- CID: content identifier for blocks.
- TID: timestamp identifier used for sortable record keys and revisions.
- CAR: content-addressed archive used for repo/block export.

## Request flow

```text
AT Protocol client
        │
        ▼
TempestWeb.Endpoint (Bandit)
        │
        ▼
TempestWeb.Router
  ├─ /xrpc/:method               -> XrpcController
  ├─ /xrpc/...subscribeRepos     -> FirehoseController / WebSocket
  ├─ /.well-known/atproto-did    -> WellKnownController
  ├─ /account/*                  -> OperatorAccountController
  ├─ /admin/*                    -> AdminController
  └─ /                            -> HomeLive
        │
        ▼
Contexts
  ├─ Accounts  -> account.sqlite via Ecto
  ├─ Identity  -> DID docs, handles, signing keys
  ├─ Records   -> per-DID repo SQLite files
  ├─ Blobs     -> account.sqlite metadata + local bytes
  ├─ Sync      -> CAR/block/blob reads
  ├─ Security  -> MFA, email tokens, grants, event log
  ├─ Admin     -> status, repo ops, backups
  └─ Sequencer -> sequencer.sqlite + PubSub fanout
```

Controllers should not build commits directly. They validate/dispatch, then
contexts handle storage, signing, sequencing, and response data.

## Storage shape

Tempest uses SQLite in three roles:

| System | Storage | Contents |
| --- | --- | --- |
| Ecto + `ecto_sqlite3` | `account.sqlite` | accounts, sessions, keys, auth, blob metadata |
| Raw `Exqlite.Sqlite3` | `repos/<did>.sqlite` | blocks, records, commits, MST metadata |
| Raw `Exqlite.Sqlite3` | `sequencer.sqlite` | global event log / firehose cursor |

Repo databases are per-DID because accounts are created dynamically and each
repo has a lifecycle independent of ordinary account metadata.

## Write cycle

A record write (`createRecord`, `putRecord`, `deleteRecord`, or `applyWrites`)
performs a complete repo commit cycle:

1. Load current MST entries from repo storage.
2. Insert, replace, or delete the record entry.
3. Rebuild the MST for correctness.
4. Sign a new commit block with the account signing key.
5. Store new CBOR blocks.
6. Update the record index and repo metadata.
7. Write a durable sequencer event.
8. Fan out the event to live firehose subscribers.

Tempest currently rebuilds the MST from scratch on writes. That is a deliberate
correctness-first tradeoff.

## Key modules

| Module | Role |
| --- | --- |
| `Tempest.Xrpc.Registry` | XRPC method table and dispatch metadata |
| `Tempest.Accounts` | accounts, sessions, auth contexts, app passwords |
| `Tempest.Security` | security inventory, MFA, email tokens, delegated access |
| `Tempest.Admin` | admin status, compatibility status, repo and backup helpers |
| `Tempest.Identity.KeyStore` | account signing key generation and storage |
| `Tempest.Records` | record write/read boundary |
| `Tempest.RepoStorage` | per-DID SQLite repository storage |
| `Tempest.RepoCore.Mst` | Merkle Search Tree implementation |
| `Tempest.RepoCore.Drisl` | deterministic DAG-CBOR subset |
| `Tempest.RepoCore.Car` | CAR v1 archive encoding/decoding |
| `Tempest.RepoCore.Commit` | signed repo commit blocks |
| `Tempest.Blobs` | blob metadata, reference lifecycle, GC |
| `Tempest.Sequencer` | durable event log and PubSub fanout |
| `Tempest.Lexicon.Validator` | runtime Lexicon validation |

## Auth shape

Legacy sessions use two credentials:

- access token: short-lived `Phoenix.Token` token
- refresh token: opaque random token stored only as a SHA-256 hash

Refresh tokens rotate. Reuse of an old rotated refresh token revokes the token
family. OAuth and app passwords share the centralized permission boundary added
for modern atproto clients.

## Supervision

```text
Tempest.Supervisor
├── TempestWeb.Telemetry
├── Tempest.Repo
├── DNSCluster
├── Phoenix.PubSub
└── TempestWeb.Endpoint
```

Firehose WebSocket connections are spawned by the web server and subscribe to
PubSub for live events after durable sequencer insertion.

## Verification

```bash
hurl --test --variable base_url=http://localhost:4000 test/smoke/health.hurl
```
