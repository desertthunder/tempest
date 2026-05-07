---
title: Hurl Smoke Tests
updated: 2026-05-07
---

Smoke tests for Tempest are Hurl files under `test/smoke/*.hurl`. They exercise the running Phoenix server over HTTP and must fail the build when an endpoint regresses.

## Layout

```text
test/smoke/
  00-foundation.hurl
  01-xrpc-shell.hurl
  02-accounts-sessions.hurl
  tempest_basic.hurl
  tempest_compat.hurl
```

## Run Commands

Single file:

```bash
hurl --test --variable base_url=http://localhost:4000 test/smoke/01-xrpc-shell.hurl
```

Full suite:

```bash
hurl --test --jobs 1 --variable base_url=http://localhost:4000 test/smoke/
```

Use `--jobs 1` when files create shared accounts or when firehose order matters.

## File Pattern

```hurl
GET {{base_url}}/xrpc/_health
HTTP 200
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.status" exists

GET {{base_url}}/xrpc/com.atproto.server.describeServer
HTTP 200
[Asserts]
header "content-type" contains "application/json"
jsonpath "$" exists
```

## Chained Auth Pattern

```hurl
POST {{base_url}}/xrpc/com.atproto.server.createSession
Content-Type: application/json
{
  "identifier": "alice.test",
  "password": "correct horse battery staple"
}
HTTP 200
[Captures]
access_jwt: jsonpath "$.accessJwt"
[Asserts]
jsonpath "$.did" exists

GET {{base_url}}/xrpc/com.atproto.server.getSession
Authorization: Bearer {{access_jwt}}
HTTP 200
[Asserts]
jsonpath "$.handle" == "alice.test"
```

## Rules

- Use `{{base_url}}`; do not hard-code localhost into Hurl files.
- Capture tokens and DIDs instead of asking shell scripts to parse JSON.
- Assert status, content type, and protocol-required fields.
- Keep destructive or account-creating suites sequential with `--jobs 1`.
- Store fixture payloads in `test/fixtures/` when request bodies become large.

## Sources

- <https://hurl.dev/docs/hurl-file.html>
- <https://hurl.dev/docs/running-tests.html>
- <https://hurl.dev/docs/capturing-response.html>
- <https://hurl.dev/docs/asserting-response.html>
