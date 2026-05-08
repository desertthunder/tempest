---
title: Sync and Firehose
updated: 2026-05-08
---

# Sync and Firehose

Sync exposes repository exports and live event streams. `sequencer.sqlite` is the source of truth for the PDS-wide event cursor.

## Endpoints

Implement:

```text
com.atproto.sync.getRepo
com.atproto.sync.getBlocks
com.atproto.sync.getLatestCommit
com.atproto.sync.getRecord
com.atproto.sync.getRepoStatus
com.atproto.sync.listBlobs
com.atproto.sync.listRepos
com.atproto.sync.requestCrawl
com.atproto.sync.subscribeRepos
```

## Event Types

The firehose emits:

- `#commit`: repository commit with CAR slice, ops, blobs, rev, and commit CID.
- `#identity`: DID document or handle may have changed.
- `#account`: hosting status changed.
- `#sync`: sync-status events described by current Lexicons.

Messages are CBOR over WebSocket. PDS firehose output includes locally hosted accounts.

## Sequencer

`repo_seq` fields:

```text
seq
did
event_type
rev
commit_cid
event_cbor
created_at
```

Rules:

- `seq` must be monotonic across the PDS.
- Backfill uses `WHERE seq > cursor ORDER BY seq ASC`.
- Live fanout broadcasts after durable insert.
- Cursor gaps should be visible to clients.
- Restart recovery must prove the durable tail cannot be lost, duplicated, or rewound.
- Torn writes must be detected and recovered without reusing a sequence number.

## Repo Export

`getRepo` returns a CAR v1 file:

- unauthenticated.
- `Content-Type: application/vnd.ipld.car`.
- root is the current commit CID.
- includes commit, MST nodes, and records needed for the requested export.

## Adversarial Checks

- Reject or mark too big commit events that exceed stream limits.
- If `since` cannot be represented safely, set `tooBig` and let consumers fetch out-of-band.
- Do not emit commit events for inactive accounts.
- Restart must not reset sequence numbers.
- WebSocket backfill must not skip rows under concurrent writes.
- Enforce the current firehose frame limit, CAR blocks limit, record block limit, and max ops per commit.
- Verify commit event fields against the signed commit block before persistence.
- Add same-rkey batch tests for `applyWrites`, including duplicate writes within one batch.
- Add MST inversion tests for generated commit events, including websocket end-to-end verification.

## HTTP Verification

```bash
curl -fsS -o /tmp/alice.car \
  "http://localhost:4000/xrpc/com.atproto.sync.getRepo?did=did:plc:example"

http GET :4000/xrpc/com.atproto.sync.getLatestCommit did==did:plc:example
http GET :4000/xrpc/com.atproto.sync.getRepoStatus did==did:plc:example

curl --no-buffer "ws://localhost:4000/xrpc/com.atproto.sync.subscribeRepos?cursor=0"
```

Expected:

- `getRepo` returns a CAR file.
- Latest commit and repo status return JSON.
- `subscribeRepos` streams CBOR WebSocket frames after repo writes.

## Sources

- <https://atproto.com/specs/sync>
- <https://atproto.com/specs/repository>
- <https://github.com/bluesky-social/atproto/blob/main/lexicons/com/atproto/sync/subscribeRepos.json>
