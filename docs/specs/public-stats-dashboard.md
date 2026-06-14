---
title: Public Stats Dashboard
updated: 2026-06-13
status: implemented
---

Reference documentation: ../reference/public-stats-dashboard.md

Verification:

```bash
curl -fsS http://localhost:4000/xrpc/_stats
curl -fsS http://localhost:4000/stats
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  test/smoke/public-stats.hurl
```
