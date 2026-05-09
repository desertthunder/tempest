---
title: Milestone 07 - Firehose
specs:
  - ../specs/sync-firehose.md
---

Goal: persist and stream repository, identity, and account events.

## Tasks

- [x] T07-01: Add `sequencer.sqlite` bootstrap.
- [x] T07-02: Add `repo_seq` table and indexes.
- [x] T07-03: Add sequencer insert API.
- [x] T07-04: Insert account and identity events during account creation/update.
- [x] T07-05: Insert commit events during record writes.
- [x] T07-06: Generate CAR slices for commit events.
- [x] T07-07: Add Phoenix.PubSub fanout after durable insert.
- [x] T07-08: Add WebSocket route for `subscribeRepos`.
- [x] T07-09: Encode event stream frames as required by current Lexicon/event stream specs.
- [x] T07-10: Add cursor backfill.
- [ ] T07-11: Add event size checks and `tooBig` behavior.
- [ ] T07-12: Add integration test for subscribe, write, receive event.
- [ ] T07-13: Add restart test proving sequence continuity.
- [ ] T07-14: Add durable-tail recovery test for crash between event persistence and fanout.
- [ ] T07-15: Add torn-write detection test for sequencer storage.
- [ ] T07-16: Add MST inversion verification for emitted commit events.
- [ ] T07-17: Add `requestCrawl` support for configured relays with rate limiting.

## Integration Tests

- New account emits identity/account/commit events.
- Record write emits commit event.
- Cursor backfill returns missed events.
- Sequence number survives restart.
- Event stream catches invalid commit/event mismatches before fanout.
- Relay crawl requests are bounded and observable.

## HTTP Verification

```bash
hurl --test --jobs 1 --variable base_url=http://localhost:4000 test/smoke/firehose.hurl
```

Expected:

- Subscriber receives a commit event with increasing `seq`.
