# Tempest's Architecture

## AT Proto

ATProto (Bluesky's protocol) is a federated social network protocol where users own their data.
The key concepts Tempest implements:

- **DID** - decentralized identity (e.g. `did:plc:abc123`) - your permanent identifier
- **Handle** - human-readable username (e.g. `alice.example.com`), resolved to a DID
- **Repo** - a personal cryptographically-signed data store per user
- **XRPC** - the HTTP RPC layer (`GET|POST /xrpc/com.atproto.repo.createRecord`)
- **Firehose** - a WebSocket stream (`subscribeRepos`) that broadcasts every write in real-time
- **MST** - Merkle Search Tree, the core data structure for repos (think: a content-addressed B-tree)
- **CAR** - Content Addressable aRchive, the binary export format for repos
- **CID** - Content Identifiers (SHA-256 hashes used as block addresses)
- **TID** - Timestamp IDs, used as record keys with monotonic guarantees

## High-Level

```text
Bluesky App / ATProto Client
        │
        ▼
  TempestWeb.Endpoint (Bandit HTTP)
        │
  ┌─────┴──────────────────────────┐
  │ Router                         │
  │  GET /xrpc/:method  ──────────►│XrpcController
  │  WebSocket /xrpc/...subscribeR │FirehoseSocket ──► Phoenix PubSub
  │  GET /.well-known/atproto-did  │WellKnownController
  │  GET /                         │PageController (landing page)
  └────────────────────────────────┘
        │
  ┌─────┴───────────┐
  │ Contexts        │
  │  Accounts       │──► account.sqlite (Ecto)
  │  Identity       │──► DNS / HTTPS resolution
  │  Records        │──► per-DID repo SQLite (raw)
  │  Sync           │──► CAR exports, block reads
  │  Sequencer      │──► sequencer.sqlite + PubSub broadcast
  └─────────────────┘
```

## Dual SQLite Strategy

Two SQLite systems running in parallel:

| System                | Driver        | Databases                     | Contents                         |
| --------------------- | ------------- | ----------------------------- | -------------------------------- |
| Ecto + `ecto_sqlite3` | Standard Ecto | `account.sqlite`              | accounts, sessions, signing keys |
| Raw `Exqlite.Sqlite3` | Manual SQL    | `repos/{did}.sqlite` per user | blocks, records, commits, MST    |
| Raw `Exqlite.Sqlite3` | Manual SQL    | `sequencer.sqlite`            | global event log (firehose)      |

Raw SQL is used for repos because each account's repo is created on demand and has a
different lifecycle than a typical Ecto repo. Fitting dynamic, per-DID databases into
Ecto's single-repo model would be awkward.

## Cryptographic Write Cycle

Every record write (`createRecord`, `putRecord`, `deleteRecord`) triggers a full commit cycle inside a `BEGIN IMMEDIATE` SQLite transaction:

1. Load current MST entries from the block store
2. Insert/delete the new entry
3. Rebuild the entire MST (produces new CBOR blocks)
4. Sign a new commit block with the account's secp256k1 key
5. Insert all new CBOR blocks into `blocks` table
6. Update `records` index
7. Update `repo_metadata` (current rev/CID)
8. Write event to `sequencer.sqlite`, broadcast via PubSub

The MST is **rebuilt from scratch** on every write (correctness-first; incremental updates are a future optimization).

## Key Modules

| Module              | Role                                                |
| ------------------- | --------------------------------------------------- |
| `RepoCore.Mst`      | Merkle Search Tree - pure Elixir, content-addressed |
| `RepoCore.Drisl`    | DAG-CBOR encoder/decoder (strict atproto subset)    |
| `RepoCore.Car`      | CAR v1 archive encoder                              |
| `RepoCore.Commit`   | Signed v3 commit blocks (secp256k1)                 |
| `RepoStorage`       | Per-DID SQLite management - 1100+ lines             |
| `Sequencer`         | Durable event log + PubSub fan-out                  |
| `Xrpc.Registry`     | Compile-time XRPC method table (O(1) dispatch)      |
| `Identity.KeyStore` | secp256k1 key gen + AES-GCM encryption at rest      |
| `Lexicon.Validator` | Runtime ATProto schema validation                   |

## Authentication

Two-token system:

- **Access tokens** - 15-minute `Phoenix.Token`-signed tokens (HMAC, not standard JWT)
- **Refresh tokens** - opaque 48-byte random tokens, stored as SHA-256 hashes, 30-day TTL

Token rotation with **reuse detection**: if a previously-rotated refresh token is presented again (replay attack), the entire token family is immediately revoked across all sessions.

## OTP Supervision Tree

```text
Tempest.Supervisor
├── TempestWeb.Telemetry
├── Tempest.Repo (Ecto/SQLite)
├── DNSCluster (multi-node ready)
├── Phoenix.PubSub (firehose fan-out only)
└── TempestWeb.Endpoint (Bandit)
```

The firehose WebSocket clients (`FirehoseSocket`) are spawned by Bandit per connection using the `WebSock` behavior.
They subscribe to PubSub directly and receive live events as messages.
