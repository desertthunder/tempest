---
title: Milestone Tasks
---

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
