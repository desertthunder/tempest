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
- client compatibility: known SDKs and clients can exercise normal flows
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
5. fixture/SDK/network tests where behavior depends on external compatibility

## Smoke tests

Important smoke files:

- `test/smoke/health.hurl`: health and storage writability
- `test/smoke/xrpc.hurl`: XRPC dispatch and protocol-shaped errors
- `test/smoke/accounts.hurl`: account/session lifecycle
- `test/smoke/identity.hurl`: local handle/DID behavior
- `test/smoke/records.hurl`: repo record writes and reads
- `test/smoke/car-sync.hurl`: CAR/block sync reads
- `test/smoke/firehose.hurl`: subscribe, write, receive event
- `test/smoke/blobs.hurl`: upload, reference, list, serve
- `test/smoke/lexicon-schemas.hurl`: known/unknown schema validation
- `test/smoke/migration-lifecycle.hurl`: migration import and lifecycle checks
- `test/smoke/oauth-security.hurl`: OAuth metadata and error-path checks
- `test/smoke/operator-account-ux.hurl`: account operator UI checks
- `test/smoke/tempest_basic.hurl`: end-to-end baseline PDS flow
- `test/smoke/tempest_compat.hurl`: compatibility hardening checks

Run suites that create accounts or depend on event order with `--jobs 1`. Use
fresh account variables for every run. `accounts.hurl` and `identity.hurl` both
use `account_handle`, so run them separately or give the full directory run a
fresh database/handle plan if both files create accounts in the same pass.

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
`applyWrites`, `getBlocks`, `requestCrawl`, and unknown AppView method fallback.

## Verification

```bash
mix test
suffix="$(date +%s)"
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  --variable suffix="${suffix}" \
  --variable account_handle="smoke-${suffix}.test" \
  --variable account_email="smoke-${suffix}@example.com" \
  --variable account_password="correct horse battery staple" \
  test/smoke/
```

## Sources

- <https://github.com/bluesky-social/atproto/tree/main/packages/atproto-interop-tests>
- <https://github.com/bluesky-social/atproto/tree/main/lexicons>
- <https://atproto.com/specs/repository>
- <https://atproto.com/specs/sync>
- <https://hurl.dev/docs/running-tests.html>
- <https://hurl.dev/docs/hurl-file.html>
