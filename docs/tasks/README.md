---
title: Milestone Tasks
---

## Milestones

1. [00 Foundation](./00-foundation.md)
2. [01 XRPC Shell](./01-xrpc-shell.md)
3. [02 Accounts and Sessions](./02-accounts-sessions.md)
4. [03 Identity and Handles](./03-identity-handles.md)
5. [04 Repository Core](./04-repo-core.md)
6. [05 Record APIs](./05-record-apis.md)
7. [06 CAR and Sync Reads](./06-car-sync-reads.md)
8. [07 Firehose](./07-firehose.md)
9. [08 Blobs](./08-blobs.md)
10. [09 Admin and Deployment](./09-admin-deployment.md)
11. [10 Compatibility Hardening](./10-compatibility-hardening.md)
12. [11 Lexicon Schemas](./11-lexicon-schemas.md)

Each file in this directory is a milestone. Each task is intended to be the smallest useful unit of work: one focused implementation change, test, or integration check.

## Status Labels

Use these labels when work starts:

```text
[ ] not started
[/] in progress
[x] done
```

## Acceptance Pattern

Every task should leave one of these behind:

- a passing unit test;
- a passing Phoenix integration test;
- a passing running-server Hurl smoke test;
- a small doc update that explains a verified behavior.

Milestone-level Hurl verification is mandatory.

## Hurl Rule

Smoke tests are Hurl files under `test/smoke/*.hurl`.

Run a single milestone:

```bash
hurl --test --variable base_url=http://localhost:4000 test/smoke/01-xrpc-shell.hurl
```

Run all smoke tests:

```bash
hurl --test --jobs 1 --variable base_url=http://localhost:4000 test/smoke/
```

Use `--jobs 1` for smoke suites that create shared accounts or depend on event order.
