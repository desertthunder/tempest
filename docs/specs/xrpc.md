---
title: XRPC HTTP Surface
updated: 2026-05-07
---

# XRPC HTTP Surface

XRPC is the public HTTP contract for the PDS. Tempest should implement the routing and error behavior before deeper PDS features.

## Requirements

- Mount all methods under `/xrpc/<method-nsid>`.
- Use `GET` for Lexicon queries and `POST` for Lexicon procedures.
- Parse URL query parameters for query methods.
- Parse JSON bodies for JSON procedures.
- Accept raw byte bodies for blob upload.
- Return JSON errors with `error` and optional `message`.
- Include CORS support where needed for clients.
- Keep XRPC error rendering in one module.

## Method Registry

Each method entry should define:

```text
nsid
kind: query | procedure | subscription
auth: none | bearer | admin
input content type
output content type
handler module/function
known errors
```

Initial methods:

```text
com.atproto.server.describeServer
com.atproto.server.createAccount
com.atproto.server.createSession
com.atproto.server.refreshSession
com.atproto.server.deleteSession
com.atproto.identity.resolveHandle
com.atproto.repo.createRecord
com.atproto.repo.putRecord
com.atproto.repo.deleteRecord
com.atproto.repo.getRecord
com.atproto.repo.listRecords
com.atproto.repo.uploadBlob
com.atproto.sync.getRepo
com.atproto.sync.getLatestCommit
com.atproto.sync.getRepoStatus
com.atproto.sync.subscribeRepos
```

## Error Shape

```json
{
  "error": "InvalidRequest",
  "message": "collection is required"
}
```

Use the correct HTTP status:

- `400` for invalid params or body.
- `401` for missing or invalid auth.
- `403` for authenticated but forbidden.
- `404` for unknown XRPC method or resource.
- `409` for compare-and-swap conflicts.
- `500` for unexpected internal errors.
- `502` for upstream service failures.

## Phoenix Notes

- The router scope is already aliased with `TempestWeb`; avoid duplicate module prefixes.
- Add a separate `:xrpc` pipeline instead of overloading the browser or generic API pipeline.
- Do not put inline JavaScript in templates.
- Do not use `Phoenix.View`.

## Adversarial Checks

- Unknown XRPC methods must not fall through to Phoenix HTML errors.
- `POST` to a query method should fail.
- `GET` to a procedure method should fail.
- Content-type mismatches should fail before handler execution.
- JSON errors should not leak stack traces.

## HTTP Verification

```bash
curl -i http://localhost:4000/xrpc/com.atproto.server.describeServer
http POST :4000/xrpc/com.atproto.server.describeServer
curl -i http://localhost:4000/xrpc/com.atproto.unknown.method
```

Expected once this spec is implemented:

- Valid `GET describeServer` returns `200` JSON.
- Invalid method/verb cases return JSON errors.

## Sources

- <https://atproto.com/specs/xrpc>
- <https://atproto.com/specs/lexicon>
