---
title: Record APIs
updated: 2026-05-07
---

# Record APIs

Record APIs expose repository reads and writes through XRPC. Handlers should stay thin and delegate validation, storage, commits, and sequencing to contexts.

## Endpoints

Implement:

```text
com.atproto.repo.createRecord
com.atproto.repo.putRecord
com.atproto.repo.deleteRecord
com.atproto.repo.getRecord
com.atproto.repo.listRecords
com.atproto.repo.describeRepo
```

Later:

```text
com.atproto.repo.applyWrites
com.atproto.repo.importRepo
```

## Write Semantics

`createRecord`:

1. Authenticate.
2. Validate input against Lexicon.
3. Resolve `repo` to the authenticated DID.
4. Validate collection NSID.
5. Generate rkey when absent.
6. Validate record `$type` and schema when known.
7. Apply compare-and-swap if `swapCommit` is present.
8. Create a repo commit.
9. Store blocks, current record row, and commit row.
10. Insert sequencer event.
11. Return `uri`, `cid`, and commit metadata.

`putRecord` must support `swapRecord` and `swapCommit`.

`deleteRecord` must remove the current record from the MST and record index without creating tombstones in the repo.

## Read Semantics

- `getRecord` resolves handle or DID and returns the current record.
- `listRecords` scans by collection and supports pagination.
- Deleted records are absent.
- Responses should include CIDs where Lexicon requires them.

## Atomicity

A write is complete only when these are durable:

```text
record block(s)
MST block(s)
signed commit block
record index update
commit metadata
sequencer event
```

If this cannot be one SQLite transaction because data spans files, use per-DID write serialization and recovery checks.

## Adversarial Checks

- The authenticated actor cannot write to another DID unless a future delegation feature permits it.
- Unknown Lexicon records may be accepted only when validation mode permits it.
- Compare-and-swap conflicts must return `409`.
- Duplicate `createRecord` with the same rkey must fail.
- Pagination cursors must not allow collection escape.

## HTTP Verification

```bash
http POST :4000/xrpc/com.atproto.repo.createRecord \
  "Authorization:Bearer $TOKEN" \
  repo=alice.test collection=app.bsky.actor.profile rkey=self \
  record:='{"$type":"app.bsky.actor.profile","displayName":"Alice"}'

http GET :4000/xrpc/com.atproto.repo.getRecord \
  repo==alice.test collection==app.bsky.actor.profile rkey==self

http GET :4000/xrpc/com.atproto.repo.listRecords \
  repo==alice.test collection==app.bsky.actor.profile
```

Expected:

- Create returns `at://<did>/app.bsky.actor.profile/self`.
- Get returns the same record and CID.
- List includes the record and stable pagination shape.

## Sources

- <https://github.com/bluesky-social/atproto/tree/main/lexicons/com/atproto/repo>
- <https://atproto.com/specs/repository>
- <https://atproto.com/specs/lexicon>
