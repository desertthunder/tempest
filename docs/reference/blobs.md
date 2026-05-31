---
title: Blobs
updated: 2026-05-31
---

Blobs are binary data uploaded outside repository records. Records refer to blobs
by CID. Tempest only exposes a blob publicly after a committed record references
it.

## Concepts

A blob is content-addressed data, commonly image or video bytes. Uploading a blob
is not enough to publish it. Publication happens when a repo record includes a
valid blob reference and that record is committed.

This split lets clients upload bytes first, then create or update records that
reference them atomically from the repo's point of view.

## Implemented endpoints

- `com.atproto.repo.uploadBlob`
- `com.atproto.sync.listBlobs`
- `com.atproto.sync.getBlob`

`uploadBlob` requires auth. Sync blob reads are public for active accounts when
the blob is public.

## Implementation

Blob metadata lives in `account.sqlite`. Local bytes live under:

```text
<TEMPEST_DATA_DIR>/blobs/<normalized-did>/<cid>
```

Tempest computes raw CIDv1 SHA-256 CIDs for uploaded bytes, validates size and
MIME boundaries, stores new uploads as temporary metadata, scans record writes
for blob references, rejects references to missing blobs, and promotes referenced
blobs after the record commit succeeds.

Deletes and updates recompute references so unreferenced blobs can be garbage
collected after their temporary grace period.

## Safety behavior

Temp uploads are not listed as public. Inactive accounts suppress blob serving.
Blob responses include defensive headers such as `X-Content-Type-Options:
nosniff` and a restrictive Content Security Policy.

Local storage is the default adapter. S3/CDN behavior is tracked separately as
operator/deployment work.

## Verification

```bash
hurl --test --jobs 1 --variable base_url=http://localhost:4000 test/smoke/blobs.hurl
```

The smoke test covers upload, reference promotion, listing, download, missing
reference rejection, and response headers.
