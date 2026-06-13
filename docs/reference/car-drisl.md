---
title: CAR and DRISL
updated: 2026-06-13
---

This page summarizes how Tempest handles AT Protocol repository CAR exports and
DRISL-encoded repository blocks.

## Repository Shape

An AT Protocol account repository is a public, self-certifying key/value store.
Keys are repo paths such as `app.bsky.actor.profile/self`; values are records.
The repository root is a signed commit object. The commit points at the root of
a Merkle Search Tree (MST), and the MST points at record blocks by CID.

The AT Protocol repository spec defines repo format version `3`. Commit objects
include:

- `did`: account DID.
- `version`: fixed `3`.
- `data`: CID link to the MST root.
- `rev`: monotonically increasing TID revision.
- `prev`: nullable previous commit CID link, required in v3.
- `sig`: compact secp256k1 commit signature bytes.

The signature is over the DRISL-encoded unsigned commit bytes. The commit itself
does not identify which public key verifies it; Tempest resolves the account DID
document and uses the `#atproto` signing key.

## CAR Files

CAR means Content Addressable aRchive. AT Protocol full repo export uses CAR v1
with MIME type `application/vnd.ipld.car`.

In an AT Protocol repo CAR:

- The first CAR root should be the current commit CID.
- The CAR must include the commit block.
- Full exports must include every MST node and record block reachable from that
  commit.
- Block order should not be trusted. Import code must tolerate arbitrary order.
- Extra unrelated blocks may exist and should not be treated as current records
  unless reachable from the commit's MST.

Tempest import flow:

1. Decode CAR v1.
2. Read the first root as the commit CID.
3. Decode the commit block.
4. Check commit CID equals the hash of the commit bytes.
5. Check commit DID equals the authenticated account DID.
6. Walk the MST and collect current record path to CID mappings.
7. Check all referenced record blocks are present.
8. Resolve the correct DID document signing key.
9. Verify the commit signature.
10. Atomically replace local repo storage with reachable blocks and current records.

For inactive migrated accounts, import must verify against the external
authoritative DID document, not the local inactive Tempest account document. The
local account has a newly generated signing key; the source CAR is signed by the
source/current PLC signing key.

## DRISL

DRISL is the deterministic CBOR profile used by atproto repositories. It is
similar in role to DAG-CBOR: it gives repository objects canonical bytes so CIDs
and signatures are reproducible.

Tempest uses DRISL for:

- commit objects;
- MST nodes;
- record blocks;
- firehose commit events.

DRISL decoding returns typed internal values for binary constructs:

- CID links decode as `%Tempest.RepoCore.Cid{}`.
- byte strings decode as `%Tempest.RepoCore.Drisl.Bytes{}`.

Those typed values are correct while verifying repository structure. They are
not JSON-safe record storage shapes. Before Tempest stores imported records as
`record_json`, it must normalize decoded values back to AT Protocol JSON:

```elixir
%Tempest.RepoCore.Cid{} -> %{"$link" => cid_string}
```

This matters for blob references. A profile avatar record may contain a DRISL CID
link under `avatar.ref`; after JSON normalization, the stored record should have:

```json
{ "avatar": { "$type": "blob", "ref": { "$link": "bafk..." } } }
```

## Public Keys

AT Protocol DID documents commonly expose the repo signing key as a Multikey:

```json
{ "id": "did:plc:...#atproto", "type": "Multikey", "publicKeyMultibase": "zQ3..." }
```

The `z...` value is base58btc Multikey. For secp256k1 keys, Tempest must:

1. base58btc-decode the value;
2. unwrap the secp256k1 public-key multicodec prefix;
3. accept compressed or uncompressed secp256k1 public-key bytes;
4. use that key for ES256K service-auth verification and repo commit signature
   verification.

Tempest also has older/internal `u...` base64url raw public-key values in local
test and generated DID documents. The shared decoder accepts both.

## References

- [AT Protocol Repository](https://atproto.com/specs/repository)
- [AT Protocol Data Model](https://atproto.com/specs/data-model)
- [AT Protocol Sync](https://atproto.com/specs/sync)
- [IPLD CAR v1 Specification](https://ipld.io/specs/transport/car/carv1/)
