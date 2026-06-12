---
title: Deployment and Observability
updated: 2026-06-03
status: implemented
---

Reference documentation:

- [Observability](../reference/deployment-observability.md)
- [Budget](../reference/budget.md)

Verification:

```bash
curl -fsS http://localhost:4000/xrpc/_health
curl -fsS http://localhost:4000/xrpc/com.atproto.server.describeServer
hurl --test --jobs 1 --variable base_url=http://localhost:4000 test/smoke/health.hurl
```
