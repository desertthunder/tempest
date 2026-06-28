---
title: Interop and Integration Testing
updated: 2026-06-03
---

Tempest treats black-box HTTP tests as the boundary between "implemented" and
"works as a PDS". Unit tests protect parsers and storage internals; Hurl smoke
tests prove behavior through the public server.

## Concepts

AT Protocol compatibility has several layers:

- syntax compatibility: DIDs, handles, NSIDs, rkeys, CIDs, AT URIs
- binary compatibility: CBOR, CAR, MST, commits, signatures
- XRPC compatibility: methods, verbs, content types, JSON error shape
- client compatibility: clients can exercise normal flows through the public
  HTTP/WebSocket contract
- network compatibility: relays/AppViews can resolve identity and sync data

A passing unit test does not prove an endpoint is usable by clients. A smoke test
must exercise the running server over HTTP/WebSocket.

### Hurl

[Hurl](https://hurl.dev/) is a command-line HTTP test runner. A `.hurl` file is
both a readable request transcript and an executable assertion suite: it sends
requests, checks status codes and headers, asserts JSON paths, and captures
response values for later requests. Tempest uses Hurl for black-box checks
because it tests the same public surface that clients use.

## Test layers

Tempest uses these layers together:

1. parser and golden tests for repo-core
2. context tests for account, identity, record, blob, and sync flows
3. Phoenix integration tests using `ConnCase`
4. running-server Hurl smoke tests under `test/smoke/`
5. deployed network tests where behavior depends on public DNS, TLS, relays, or
   AppViews

## Smoke tests

- `test/smoke/health.hurl`: health and storage writability
- `test/smoke/xrpc.hurl`: XRPC dispatch and protocol-shaped errors
- `test/smoke/accounts.hurl`: account/session lifecycle
- `test/smoke/identity.hurl`: local handle/DID behavior
- `test/smoke/identity-correctness.hurl`: .well-known/atproto-did, resolveHandle, and session agreement
- `test/smoke/records.hurl`: repo record writes and reads
- `test/smoke/car-sync.hurl`: CAR/block sync reads
- `test/smoke/firehose.hurl`: subscribe, write, receive event
- `test/smoke/blobs.hurl`: upload, reference, list, serve
- `test/smoke/lexicon-schemas.hurl`: known/unknown schema validation
- `test/smoke/migration-lifecycle.hurl`: migration import and lifecycle checks
- `test/smoke/oauth-security.hurl`: OAuth metadata and error-path checks
- `test/smoke/operator-account-ux.hurl`: account operator UI checks
- `test/smoke/account-management.hurl`: account control panel browser UI (login, dashboard, sub-pages)
- `test/smoke/account-management-admin.hurl`: admin control panel browser UI (requires admin auth)
- `test/smoke/email-security.hurl`: password reset request and token consumption (requires operator-supplied token)
- `test/smoke/tempest_basic.hurl`: end-to-end baseline PDS flow
- `test/smoke/tempest_compat.hurl`: compatibility hardening checks
- `test/smoke/deployment.hurl`: non-destructive deployed HTTPS smoke checks
- `test/smoke/deployed/crawlers.hurl`: deployed relay crawler fan-out checks

Run suites that create accounts or depend on event order with `--jobs 1`. Use
fresh account variables for every run. `accounts.hurl` and `identity.hurl` both
use `account_handle`, so run them separately or give the full directory run a
fresh database/handle plan if both files create accounts in the same pass.
Do not include `test/smoke/deployment.hurl` in local wildcard runs; it requires
a deployed HTTPS hostname and an admin token.

## Hurl rules

- Use `{{base_url}}`; do not hard-code localhost into Hurl files.
- Capture tokens and DIDs instead of parsing JSON in shell scripts.
- Assert status, content type, and protocol-required fields.
- Run account-creating suites with `--jobs 1` and fresh variables.
- Store large request bodies in `test/fixtures/`.

## Run commands

Start the server first:

```bash
mix phx.server
```

Health check:

```bash
hurl --test --variable base_url=http://localhost:4000 test/smoke/health.hurl
```

Account/session flow:

```bash
suffix="$(date +%s)"
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  --variable account_handle="smoke-${suffix}.test" \
  --variable account_email="smoke-${suffix}@example.com" \
  --variable account_password="correct horse battery staple" \
  test/smoke/accounts.hurl
```

Operator account UI:

```bash
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  --variable suffix="$(date +%s)" \
  test/smoke/operator-account-ux.hurl
```

## Compatibility smoke coverage

`tempest_basic.hurl` covers the baseline appliance flow: health, server metadata,
account creation, profile write/read, repo CAR export, blob upload/reference, and
firehose observation.

`tempest_compat.hurl` covers compatibility extras: private preference endpoints,
`applyWrites`, `getBlocks`, and unknown AppView method fallback.

`test/smoke/deployed/crawlers.hurl` covers `requestCrawl` against configured
relays. Run it only against a publicly reachable deployment, because real relays
such as `bsky.network` and `vsky.network` reject `localhost` and private hostnames.
The full deployed relay/AppView procedure lives in
[`deployment-observability`](./deployment-observability.md#relay-and-appview-crawl-verification).

## Verification

```bash
mix test
test/smoke/local-pds-compat.sh http://localhost:4000
```

For broader local smoke runs, list local files explicitly. Do not use
`test/smoke/*.hurl`, because `test/smoke/deployment.hurl` is deployed-only.

Deployed crawler check:

```bash
hurl --test --jobs 1 \
  --variable base_url=https://tempest.example.com \
  --variable crawler_hostname=tempest.example.com \
  test/smoke/deployed/crawlers.hurl
```

Deployed HTTPS smoke check:

```bash
hurl --test --jobs 1 \
  --variable base_url=https://tempest.example.com \
  --variable admin_token="$ADMIN_TOKEN" \
  test/smoke/deployment.hurl
```

## Sources

- <https://github.com/bluesky-social/atproto/tree/main/lexicons>
- <https://atproto.com/specs/repository>
- <https://atproto.com/specs/sync>
- <https://hurl.dev/docs/running-tests.html>
- <https://hurl.dev/docs/hurl-file.html>
