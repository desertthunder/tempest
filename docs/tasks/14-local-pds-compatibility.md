---
title: Milestone 14 - Local PDS Compatibility Testing
specs:
  - ../specs/pds-compatibility.md
  - ../specs/interop-testing.md
  - ../specs/security-oauth.md
  - ../specs/migration-lifecycle.md
---

Goal: prove Tempest's PDS behavior locally before relying on deployment,
public DNS, TLS, relays, or AppViews.

Use `ConnCase` for detailed endpoint checks. Keep Hurl for running-server smoke
coverage and use SDK tests where client behavior matters.

- [x] T14-01: Keep the endpoint compatibility matrix aligned with implemented
      behavior and reference Lexicons.
- [x] T14-02: Add ConnCase response-shape and error-shape tests for core PDS
      endpoints.
- [ ] T14-03: Add ConnCase auth tests for bearer tokens, app passwords, OAuth
      tokens, admin tokens, and missing credentials.
- [ ] T14-04: Add ConnCase content-type and verb tests for XRPC endpoints.
- [ ] T14-05: Add SDK black-box tests for login, write, read, blob, CAR, and
      firehose flows against a local server.
- [ ] T14-06: Add OAuth and app-password black-box compatibility tests.
- [ ] T14-07: Add migration-in and migration-out compatibility tests using two
      local Tempest instances.
- [ ] T14-08: Add an explicit AppView proxy/fallback policy and local coverage
      for unknown `app.bsky.*` methods.
- [ ] T14-09: Integrate official AT Protocol interop fixtures where practical.
- [ ] T14-10: Add firehose frame comparison tests for header/body CBOR shape,
      backfill, live events, and deactivated accounts.
- [ ] T14-11: Add local restore-drill test that verifies DBs, repos, blobs,
      signing keys, and OAuth keys together.
- [ ] T14-12: Add local Hurl smoke profile that runs the completed compatibility
      suites without deployment.

## Integration Tests

- ConnCase covers request parsing, auth, response shape, and error shape for the
  endpoint matrix.
- SDK tests can create an account, authenticate, write records, upload blobs,
  read records, export CAR, and observe firehose events.
- OAuth and app-password flows work through public HTTP endpoints, not internal
  context calls.
- Migration tests prove import, activation, deactivation, service auth, missing
  blob listing, and migration-out behavior.
- AppView fallback behavior is documented and tested with mocked outbound HTTP.
- Restore drill produces a server state that passes read-only smoke tests.

## HTTP Verification

```bash
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  test/smoke/tempest_basic.hurl \
  test/smoke/tempest_compat.hurl \
  test/smoke/oauth-security.hurl \
  test/smoke/migration-lifecycle.hurl
```
