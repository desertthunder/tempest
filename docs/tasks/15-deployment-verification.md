---
title: Milestone 15 - Deployment and Post-deployment Verification
specs:
  - ../specs/admin-operations.md
  - ../specs/deployment-observability.md
  - ../specs/pds-compatibility.md
references:
  - ../reference/deployment-observability.md
  - ../reference/budget.md
---

Completed [June 13, 2026](../../CHANGELOG.md#2026-06-13).

## Verification

```bash
hurl --test --jobs 1 \
  --variable base_url=https://tempest.example.com \
  --variable admin_token="$ADMIN_TOKEN" \
  test/smoke/deployment.hurl
```

Deployment verification covers release/container boot, durable volume
requirements, production secret checks, S3/R2-backed backup and blob profiles,
restore drills, public DID/handle verification, relay/AppView crawl checks, and
real-client smoke flows.

Reference documentation:

- [Deployment Guide](../reference/deployment.md)
- [Deployment and Observability](../reference/deployment-observability.md)
- [Budget Deployment](../reference/budget.md)
- [PDS Compatibility Matrix](../reference/pds-compatibility.md)
