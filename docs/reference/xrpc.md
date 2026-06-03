---
title: XRPC HTTP Surface
updated: 2026-06-03
---

XRPC is the public HTTP RPC layer used by AT Protocol clients and services.
Tempest exposes XRPC methods under `/xrpc/<method-nsid>`.

## Concepts

A Lexicon method has an NSID such as `com.atproto.repo.createRecord`. Methods are
queries, procedures, or subscriptions:

- queries usually use `GET` and URL query parameters
- procedures use `POST` and a JSON or byte body
- subscriptions upgrade to a streaming protocol such as WebSocket

Errors are protocol-shaped JSON with an `error` string and optional `message`.

## Implementation

`TempestWeb.Router` sends protocol methods through the XRPC pipeline.
`Tempest.Xrpc.Registry` is the method table. `_health` is public, and
`_admin/status` is protected by admin-token auth outside normal account bearer
credentials. Each registry entry declares:

- NSID
- kind (`query`, `procedure`, `subscription`)
- auth requirement
- input/output content type
- handler module/function
- known errors

`TempestWeb.XrpcController` performs registry lookup, method checks, content
handling, auth assignment, and error rendering before calling the handler.

Handlers live under `Tempest.Xrpc.*` and should remain thin. Long-running or
stateful work belongs in contexts such as `Tempest.Accounts`, `Tempest.Records`,
`Tempest.Sync`, or `Tempest.Blobs`.

## Error behavior

Unknown methods return JSON, not Phoenix HTML errors. Verb mismatches and content
mismatches fail before handler execution.

Common status mappings:

- `400`: invalid params/body
- `401`: missing or invalid auth
- `403`: authenticated but forbidden
- `404`: unknown method or missing resource
- `409`: compare-and-swap conflict
- `500`: unexpected internal error
- `502`: upstream failure

## Verification

```bash
hurl --test --variable base_url=http://localhost:4000 test/smoke/xrpc.hurl
```

The smoke test covers health, method dispatch, unknown methods, and verb/error
shape behavior.
