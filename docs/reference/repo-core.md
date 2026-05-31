---
title: Repository Core
updated: 2026-05-31
---

Repo-core is Tempest's content-addressed repository engine. It is implemented in
pure Elixir and is the byte-level compatibility boundary for records, commits,
CAR exports, and firehose commit slices.

## Concepts

An AT Protocol repository is a signed data store for one DID. Records live at
paths shaped like:

```text
<collection-nsid>/<record-key>
```

The current set of records is represented by a Merkle Search Tree (MST). Record
blocks, MST nodes, and commit blocks are content-addressed by CIDs. A commit signs
the current root and gives the repo a new revision (`rev`).

A CAR file is a portable bundle of content-addressed blocks. Sync endpoints use
CAR to export repo data or selected blocks.

## Implementation

Important modules under `Tempest.RepoCore` include:

- `AtUri`, `Did`, `Handle`, `Nsid`, `RecordKey`, `Tid`: syntax and identifiers
- `Cid`: CID encoding/decoding
- `Drisl`: deterministic DAG-CBOR subset used by atproto data
- `Car`: CAR v1 encode/decode
- `Mst`: deterministic Merkle Search Tree operations
- `Commit`: signed repository commit creation and verification

`Tempest.RepoStorage` persists blocks, records, commits, and metadata in a
per-DID SQLite database. Record writes rebuild the MST for correctness, sign a
new commit, store new blocks, update indexes, and emit a sequencer event.

## Compatibility notes

The repo engine enforces canonical encoding, CID digest checks, syntax checks,
and decode limits. Tests cover parser behavior, CBOR/CAR round trips, MST
operations, commit signatures, and storage persistence.

Correctness matters more than incremental MST performance. Rebuilding the MST on
write is acceptable until profiling proves otherwise.

## Verification

```bash
mix test test/tempest/repo_core test/tempest/repo_storage_test.exs
hurl --test --jobs 1 --variable base_url=http://localhost:4000 test/smoke/records.hurl
hurl --test --jobs 1 --variable base_url=http://localhost:4000 test/smoke/car-sync.hurl
```
