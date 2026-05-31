---
title: Record APIs
updated: 2026-05-31
---

Record APIs expose repository reads and writes through XRPC. They are the main
way clients create profile records, posts, follows, custom app records, and other
atproto data.

## Concepts

A record belongs to a collection NSID and has a record key (`rkey`). Together
with the account DID they form an AT URI:

```text
at://<did>/<collection>/<rkey>
```

Writes create signed repository commits. Reads return the current record and CID.
Deleted records disappear from the current repo view; the repo history is carried
by commits and blocks rather than application-level tombstone rows.

## Implemented endpoints

- `com.atproto.repo.createRecord`
- `com.atproto.repo.putRecord`
- `com.atproto.repo.deleteRecord`
- `com.atproto.repo.applyWrites`
- `com.atproto.repo.getRecord`
- `com.atproto.repo.listRecords`
- `com.atproto.repo.describeRepo`

Write endpoints require auth. Read endpoints are public for hosted active repos.

## Write path

A write validates input, checks authorization, validates collection/rkey syntax,
validates the record against known Lexicons when possible, applies swap checks,
updates repo storage, signs a new commit, and writes a sequencer event.

`createRecord` can generate an rkey when absent. `putRecord` replaces or creates
a specific rkey. `deleteRecord` removes the current record from the MST and record
index. `applyWrites` batches multiple create/update/delete operations.

Compare-and-swap fields protect callers from overwriting unexpected repo or
record state. Conflicts return protocol-shaped errors.

## Read path

`getRecord` fetches one current record. `listRecords` scans a collection with
pagination. `describeRepo` reports repo metadata and available collections.

## Verification

```bash
hurl --test --jobs 1 --variable base_url=http://localhost:4000 test/smoke/records.hurl
```

The smoke test covers create, put, delete, get, list, compare-and-swap behavior,
and record validation boundaries.
