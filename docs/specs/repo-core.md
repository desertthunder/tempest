---
title: Repository Core
updated: 2026-05-08
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
- TIDs are 13-character base32-sortable strings built from a 53-bit UNIX microsecond timestamp and 10-bit clock id.
- Repository format is v3.
- Commits include `did`, `version`, `data`, `rev`, `prev`, and `sig`.
- In v3, `prev` must exist and is usually `null`.
- The commit `rev` is a TID logical clock and must increase per repo.
- CIDs are CIDv1 using DRISL-CBOR (`dag-cbor`, `0x71`) or raw (`0x55`) codecs, sha-256 multihashes, and lowercase `b` base32 strings outside CBOR.
- DRISL-CBOR is deterministic shortest-form CBOR with string-only map keys, bytewise encoded-key map ordering, no indefinite-length items, no floats for atproto data, and only tag 42 for CID links.
- CBOR decoders must enforce input-size, nesting-depth, item-count, collection-length, string-size, and byte-string-size limits.
- CAR v1 files use a DRISL metadata header with `version: 1` and `roots`, followed by varint-length-prefixed `{CID, block bytes}` sections.
- CAR readers and writers must verify that section CIDs match the SHA-256 digest of their block bytes, tolerate arbitrary block order and duplicate blocks, and enforce size/count limits.
- MST shape must be deterministic from current key/value contents.
- MST key depth uses SHA-256 and counts leading zero bits in two-bit chunks.
- Repository export uses CAR v1 with MIME type `application/vnd.ipld.car`.

## Implementation Boundary

Repo-core is implemented in pure Elixir. Do not use Rustler for repository primitives unless this spec is explicitly revised.

Golden tests and official atproto vectors are the compatibility boundary for byte-level work.

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

- TID official syntax examples and monotonic generation.
- CID known bytes to known string.
- DRISL CBOR known object to known bytes.
- CBOR decoder limit and non-canonical encoding rejection cases.
- CAR v1 known bytes round trip and malformed archive rejection.
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
- <https://atproto.com/specs/data-model>
- <https://dasl.ing/drisl.html>
- <https://dasl.ing/car.html>
- <https://ipld.io/specs/transport/car/carv1/>
- <https://www.rfc-editor.org/rfc/rfc8949>
- <https://atproto.com/guides/data-repos>
- <https://github.com/bluesky-social/atproto/tree/main/packages/repo>
- <https://github.com/bluesky-social/atproto/tree/main/packages/atproto-interop-tests>
