---
title: Blobs
updated: 2026-05-07
---

# Blobs

Blobs are uploaded separately from records and become public only when a committed record references them.

## Endpoints

Implement:

```text
com.atproto.repo.uploadBlob
com.atproto.sync.getBlob
com.atproto.sync.listBlobs
```

Optional public route for direct serving can follow after `getBlob`.

## Blob CID

Generated blob CIDs use:

```text
CIDv1
raw codec
sha-256, 256-bit hash
base32 string encoding outside CBOR
```

## Lifecycle

```text
upload
  -> validate declared size and MIME
  -> sniff MIME where possible
  -> compute CID
  -> store temp bytes
  -> insert metadata

record write
  -> scan record for blob references
  -> verify each blob exists for the DID
  -> mark referenced blobs public after commit

record delete
  -> recompute references
  -> delete blob if no current record references it

garbage collection
  -> delete unreferenced temp blobs after TTL
```

## Storage

Default path:

```text
<TEMPEST_DATA_DIR>/blobs/<normalized-did>/<cid>
```

The storage adapter must support:

- put temp blob.
- promote referenced blob.
- get blob with content length and MIME.
- delete blob.
- list by DID and optional cursor.

S3-compatible storage is a later adapter, not the default.

## Adversarial Checks

- Reject uploads whose actual size differs from `Content-Length`.
- Reject files larger than the configured limit.
- Do not make temp uploads public.
- Do not delete a blob still referenced by any current record.
- Account deactivation, takedown, suspension, and deletion must suppress blob serving.

## HTTP Verification

```bash
printf 'hello blob' > /tmp/tempest-blob.txt

http --form POST :4000/xrpc/com.atproto.repo.uploadBlob \
  "Authorization:Bearer $TOKEN" \
  Content-Type:text/plain < /tmp/tempest-blob.txt

http GET :4000/xrpc/com.atproto.sync.listBlobs \
  did==did:plc:example

curl -fsS -H "Authorization: Bearer $TOKEN" \
  "http://localhost:4000/xrpc/com.atproto.sync.getBlob?did=did:plc:example&cid=bafk..."
```

Expected:

- Upload returns a Lexicon blob object.
- Temp blobs do not appear in `listBlobs`.
- Referenced blobs are downloadable with correct `Content-Type` and `Content-Length`.

## Sources

- <https://atproto.com/specs/blob>
- <https://atproto.com/guides/blob-lifecycle>
- <https://atproto.com/specs/xrpc>
