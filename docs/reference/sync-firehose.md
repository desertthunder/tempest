---
title: Sync and Firehose (Reference)
updated: 2026-05-31
---

Tempest exposes read-only sync exports and a live event stream ("firehose").

The firehose cursor is backed by `sequencer.sqlite` (`repo_seq` table). Sequence
numbers are global and monotonic within a Tempest instance.

## Endpoints

Sync reads:

- `com.atproto.sync.getRepo` (CAR)
- `com.atproto.sync.getBlocks` (CAR)
- `com.atproto.sync.getRecord` (CAR)
- `com.atproto.sync.getLatestCommit` (JSON)
- `com.atproto.sync.getRepoStatus` (JSON)
- `com.atproto.sync.listRepos` (JSON)
- `com.atproto.sync.listBlobs` (JSON)
- `com.atproto.sync.getBlob` (bytes)

Firehose:

- `com.atproto.sync.subscribeRepos` (WebSocket, CBOR frames)

Relay hint:

- `com.atproto.sync.requestCrawl` (JSON)

## Firehose usage

Connect:

- `ws(s)://<host>/xrpc/com.atproto.sync.subscribeRepos?cursor=<seq>`

Rules:

- If `cursor` is provided, Tempest backfills events with `seq > cursor` before
  switching to live fanout.
- Events are emitted only after a durable insert into `sequencer.sqlite`.

### Event kinds

Tempest emits the atproto eventstream envelope types:

- `#commit`
- `#identity`
- `#account`
- `#sync`

## Verification

Smoke test:

```bash
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  test/smoke/firehose.hurl
```

This test exercises: subscribe, write, receive a commit event with increasing
`seq`.

## Current limitations

- This page documents Tempest's firehose behavior *within one instance*.
  Federation-wide delivery (external relays/AppViews) depends on deployment and
  interoperability work tracked elsewhere.
- `requestCrawl` behavior is compatibility-sensitive; treat it as an interop
  surface and keep `test/smoke/tempest_compat.hurl` green.
