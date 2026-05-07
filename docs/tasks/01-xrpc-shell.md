---
title: Milestone 01 - XRPC Shell
specs:
  - ../specs/xrpc.md
---

Goal: expose the XRPC routing, method registry, and protocol-shaped JSON errors.

## Tasks

- [ ] T01-01: Add a dedicated XRPC router pipeline.
- [ ] T01-02: Add `Tempest.Xrpc.Method` metadata struct.
- [ ] T01-03: Add `Tempest.Xrpc.Registry` with initial method definitions.
- [ ] T01-04: Add shared JSON error renderer.
- [ ] T01-05: Add verb mismatch handling for query/procedure methods.
- [ ] T01-06: Implement `com.atproto.server.describeServer`.
- [ ] T01-07: Add controller tests for unknown method JSON error.
- [ ] T01-08: Add controller tests for wrong HTTP verb.
- [ ] T01-09: Add response content-type assertions.
- [ ] T01-10: Add smoke script entries for health and describeServer.

## Integration Tests

- `GET describeServer` returns JSON.
- `POST describeServer` returns JSON error.
- Unknown XRPC method returns JSON error.

## HTTP Verification

```bash
http GET :4000/xrpc/com.atproto.server.describeServer
http POST :4000/xrpc/com.atproto.server.describeServer
curl -i http://localhost:4000/xrpc/com.atproto.unknown.method
```

Expected:

- `describeServer` has available user domains, invite policy, and links placeholders as applicable.
- Errors use `{"error": "...", "message": "..."}`.

## Done

Run:

```bash
mix precommit
```
