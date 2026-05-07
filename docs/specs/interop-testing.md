---
title: Interop and Integration Testing
updated: 2026-05-07
---

# Interop and Integration Testing

Protocol work is not done until it passes black-box tests. Unit tests protect parsers and binary code, but every milestone needs an HTTP test that exercises the running Phoenix server.

## Test Layers

1. Parser and golden tests for repo-core.
2. Context tests for account, identity, record, blob, and sync flows.
3. Phoenix integration tests using `ConnCase`.
4. Running-server smoke tests with `curl` and `http`.
5. External fixture tests against official atproto fixtures.
6. Client compatibility tests against known SDKs or `goat` where useful.

## Smoke Test Script

Create `script/smoke/tempest_basic.sh` once Milestone 02 lands. It should:

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

## HTTP Verification

```bash
script/smoke/tempest_basic.sh http://localhost:4000
```

Expected:

- The script exits non-zero on any failed HTTP check.
- The script prints each endpoint and status.
- The script leaves enough IDs in output to debug failures.

## Sources

- <https://github.com/bluesky-social/atproto/tree/main/packages/atproto-interop-tests>
- <https://github.com/bluesky-social/atproto/tree/main/lexicons>
- <https://atproto.com/specs/repository>
- <https://atproto.com/specs/sync>
