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
10. [09 Lexicon Schemas](./09-lexicon-schemas.md)
11. [10 Compatibility Hardening](./10-compatibility-hardening.md)
12. [11 Security, OAuth, and Delegated Access](./11-security-oauth.md)
13. [12 Migration and Account Lifecycle](./12-migration-lifecycle.md)
14. [13 Admin, Storage, and Operator Features](./13-admin-operator-features.md)
15. [14 Local PDS Compatibility Testing](./14-local-pds-compatibility.md)
16. [15 Deployment and Post-deployment Verification](./15-deployment-verification.md)

Each file in this directory is a milestone. Each task is intended to be the
smallest useful unit of work: one focused implementation change, test, or
integration check.

## Target Profile Priority Map (Solo Login + Archive)

Blocking work for the current target profile (see `docs/specs/target-profile.md`):

- Compatibility stays green: `test/smoke/tempest_basic.hurl` and
  `test/smoke/tempest_compat.hurl` must pass.
- Feature work lands first: admin auth/status, repo and backup commands,
  S3/R2 adapters, SMTP, telemetry, and operator UI.
- Local compatibility testing follows without requiring deployment: ConnCase
  endpoint checks, SDK tests, local Hurl smoke tests, migration tests, and
  restore drills.
- Deployment work comes after local proof: release config, Docker, reverse
  proxy docs, managed PaaS docs, persistent volume requirements, and R2 docs.
- Post-deployment testing proves external DID/handle verification, HTTPS XRPC,
  WebSocket firehose behavior, relay/AppView crawl, and real-client flows.

Deprioritized behind the above for this profile:

- migration and lifecycle between PDS instances (Milestone 12)
- MFA and advanced account/security UX (parts of Milestone 11/14)
- hosted-provider scale features


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
