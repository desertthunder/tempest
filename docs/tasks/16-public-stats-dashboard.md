---
title: Milestone 16 - Public Stats Dashboard
specs:
  - ../specs/public-stats-dashboard.md
  - ../specs/deployment-observability.md
  - ../specs/admin-operations.md
references:
  - ../reference/deployment-observability.md
  - ../reference/admin-operations.md
---

Completed [June 14, 2026](../../CHANGELOG.md#2026-06-14).

## Verification

```bash
curl -fsS http://localhost:4000/xrpc/_stats
curl -fsS http://localhost:4000/stats
curl -fsS http://localhost:4000/changelog
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  test/smoke/public-stats.hurl
```

Public stats expose sanitized aggregate and bounded activity data without auth,
keep admin-only status protected, omit sensitive fields, and render
`CHANGELOG.md` through a constrained desktop document route.

Reference documentation: [Public Stats Dashboard](../reference/public-stats-dashboard.md).
