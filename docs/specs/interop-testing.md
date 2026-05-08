---
title: Interop and Integration Testing
updated: 2026-05-08
---

Protocol work is not done until it passes black-box tests. Unit tests protect parsers and binary code, but every milestone needs an HTTP test that exercises the running Phoenix server.

## Test Layers

1. Parser and golden tests for repo-core.
2. Context tests for account, identity, record, blob, and sync flows.
3. Phoenix integration tests using `ConnCase`.
4. Running-server smoke tests with Hurl.
5. External fixture tests against official atproto fixtures.
6. Client compatibility tests against known SDKs or `goat` where useful.

## Coverage Tracking

Maintain an endpoint and behavior checklist against the official Lexicons, protocol specs, reference PDS behavior where useful, and known SDK expectations. The checklist is not a source of protocol truth; it is a way to keep compatibility gaps visible.

Track at least:

- Account security and recovery: email confirmation, email update, password reset, app passwords, OAuth grants, MFA-ready credential state, and security events.
- Migration and lifecycle: service auth, account status, activation/deactivation, deletion requests, signing-key reservation, PLC operation flows, `importRepo`, and missing blob accounting.
- Sync completeness: `getRepo`, `getBlocks`, `getLatestCommit`, `getRecord`, `getRepoStatus`, `listBlobs`, `listRepos`, `requestCrawl`, `subscribeRepos`, frame limits, durable restart behavior, and MST inversion checks.
- Blob operations: temp/public lifecycle, defensive download headers, inactive-account suppression, local storage, S3-compatible storage, and optional CDN redirects.
- Operator surface: invite management, admin status, repo verify/export/import, blob GC, backup/restore drills, telemetry, and deployment recipes.
- Compatibility extras: private preferences endpoints and XRPC proxy fallback rules for service endpoints that should be proxied instead of implemented locally.

## Smoke Tests

Create `test/smoke/tempest_basic.hurl` once Milestone 02 lands. It should:

1. Hit health.
2. Call `describeServer`.
3. Create account.
4. Create session.
5. Create profile record.
6. Fetch profile record.
7. Export repo CAR.
8. Upload blob.
9. Reference blob from a record.
10. Connect to firehose and observe a commit event.

## Integration Test Rules

- Keep smoke tests in `test/smoke/*.hurl`.
- Run smoke tests with `hurl --test`.
- Pass environment-specific values with Hurl variables, for example `--variable base_url=http://localhost:4000`.
- Prefer selectors and structured response assertions over raw HTML.
- Use `start_supervised!/1` for test processes.
- Avoid `Process.sleep/1`; use monitors or `:sys.get_state/1`.
- Use isolated data directories per test.
- Keep external network tests opt-in.
- Store protocol fixture versions in the repo.

## Adversarial Checks

- Restart the server and rerun read checks.
- Reuse old refresh tokens and ensure they fail.
- Try writing to another user's DID.
- Try invalid handles, DIDs, NSIDs, rkeys, CIDs, and AT URIs.
- Try oversize blob uploads.
- Try firehose cursor backfill while writes are happening.
- Compare coverage against the official endpoint and behavior checklist before calling a subsystem complete.

## HTTP Verification

```bash
hurl --test --jobs 1 --variable base_url=http://localhost:4000 test/smoke/tempest_basic.hurl
```

Expected:

- Hurl exits non-zero on any failed HTTP check.
- Captures expose enough IDs to debug failures.
- Assertions cover status, content type, and required JSON fields.

## Sources

- <https://github.com/bluesky-social/atproto/tree/main/packages/atproto-interop-tests>
- <https://github.com/bluesky-social/atproto/tree/main/lexicons>
- <https://atproto.com/specs/repository>
- <https://atproto.com/specs/sync>
- <https://hurl.dev/docs/running-tests.html>
- <https://hurl.dev/docs/hurl-file.html>
