---
title: Repository Core
updated: 2026-05-07
---

Repo-core is the highest-risk subsystem. Treat it as a small storage engine with strict binary compatibility requirements.

## Required Primitives

```text
AT URI parser
NSID parser
Record key parser
TID generator
CID encoding and decoding
DRISL CBOR encoding and decoding
CAR v1 reader and writer
MST insert/get/delete/range
commit creation
commit signing and verification
repo diff generation
block graph traversal
```

## Repository Facts

- Repo paths are `<collection>/<record-key>`.
- Collections are valid normalized NSIDs.
- Repository format is v3.
- Commits include `did`, `version`, `data`, `rev`, `prev`, and `sig`.
- In v3, `prev` must exist and is usually `null`.
- The commit `rev` is a TID logical clock and must increase per repo.
- MST shape must be deterministic from current key/value contents.
- MST key depth uses SHA-256 and counts leading zero bits in two-bit chunks.
- Repository export uses CAR v1 with MIME type `application/vnd.ipld.car`.

## Implementation Boundary

Pure Elixir is acceptable only if golden tests prove compatibility. Rustler is acceptable for byte-level work.

Candidate API:

```elixir
defmodule Tempest.RepoCore.Engine do
  @callback apply_writes(binary(), list(map()), map()) ::
              {:ok,
               %{
                 rev: String.t(),
                 root_cid: String.t(),
                 commit_cid: String.t(),
                 commit_bytes: binary(),
                 blocks: list({String.t(), binary()}),
                 ops: list(map())
               }}
              | {:error, term()}
end
```

## Golden Tests

Required before record write endpoints are considered complete:

- CID known bytes to known string.
- DRISL CBOR known object to known bytes.
- MST depth examples from the official spec.
- MST insert/get/delete/range.
- Commit signing and verification.
- CAR export/import round trip.
- Repo diff operation inversion against fixtures.

## Adversarial Checks

- Decode limits must protect against deep CBOR nesting and oversized objects.
- CAR import must ignore unreferenced blocks.
- CAR import must reject incomplete repo graphs.
- Record key mining must not create unbounded MST node size or depth.
- Commit verification must use the DID document signing key.

## HTTP Verification

Repo-core itself is internal, so its black-box check is the first endpoint that depends on it:

```bash
http POST :4000/xrpc/com.atproto.repo.createRecord \
  "Authorization:Bearer $TOKEN" \
  repo=alice.test collection=app.bsky.actor.profile \
  record:='{"$type":"app.bsky.actor.profile","displayName":"Alice"}'

http GET :4000/xrpc/com.atproto.sync.getLatestCommit did==did:plc:example
```

Expected once repo-core and record writes are implemented:

- Record creation returns `uri`, `cid`, and commit metadata.
- Latest commit returns a monotonic `rev` and commit CID.

## Sources

- <https://atproto.com/specs/repository>
- <https://atproto.com/guides/data-repos>
- <https://github.com/bluesky-social/atproto/tree/main/packages/repo>
- <https://github.com/bluesky-social/atproto/tree/main/packages/atproto-interop-tests>
