---
title: Milestone 07 - Firehose
specs:
  - ../specs/sync-firehose.md
---

Goal: persist and stream repository, identity, and account events.

## Tasks

- [ ] T07-01: Add `sequencer.sqlite` bootstrap.
- [ ] T07-02: Add `repo_seq` table and indexes.
- [ ] T07-03: Add sequencer insert API.
- [ ] T07-04: Insert account and identity events during account creation/update.
- [ ] T07-05: Insert commit events during record writes.
- [ ] T07-06: Generate CAR slices for commit events.
- [ ] T07-07: Add Phoenix.PubSub fanout after durable insert.
- [ ] T07-08: Add WebSocket route for `subscribeRepos`.
- [ ] T07-09: Encode event stream frames as required by current Lexicon/event stream specs.
- [ ] T07-10: Add cursor backfill.
- [ ] T07-11: Add event size checks and `tooBig` behavior.
- [ ] T07-12: Add integration test for subscribe, write, receive event.
- [ ] T07-13: Add restart test proving sequence continuity.

## Integration Tests

- New account emits identity/account/commit events.
- Record write emits commit event.
- Cursor backfill returns missed events.
- Sequence number survives restart.

## HTTP Verification

Terminal 1:

```bash
curl --no-buffer "ws://localhost:4000/xrpc/com.atproto.sync.subscribeRepos?cursor=0"
```

Terminal 2:

```bash
http POST :4000/xrpc/com.atproto.repo.createRecord \
  "Authorization:Bearer $TOKEN" \
  repo=alice.test collection=app.bsky.feed.post \
  record:='{"$type":"app.bsky.feed.post","text":"firehose test","createdAt":"2026-05-07T00:00:00Z"}'
```

Expected:

- Subscriber receives a commit event with increasing `seq`.

## Done

Run:

```bash
mix precommit
```
