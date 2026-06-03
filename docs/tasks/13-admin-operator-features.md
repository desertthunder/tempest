---
title: Milestone 13 - Admin, Storage, and Operator Features
specs:
  - ../specs/admin-operations.md
  - ../specs/deployment-observability.md
  - ../specs/security-oauth.md
  - ../specs/pds-compatibility.md
---

Completed [June 3, 2026](../../CHANGELOG.md#2026-06-03).

## Verification

```bash
mix test
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  --variable suffix="$(date +%s)" \
  test/smoke/operator-account-ux.hurl
```

The smoke test verifies account UI auth, repo browsing, blob browsing, sequencer
filters, and firehose frame display. ConnCase covers account/admin UI route
rendering, admin status auth, and rejection of normal account tokens on admin
routes.

Reference documentation:

- [Admin and Operator Operations](../reference/admin-operations.md)
- [Deployment and Observability](../reference/deployment-observability.md)
- [Security, OAuth, and Delegated Access](../reference/security-oauth.md)
- [PDS Compatibility Matrix](../reference/pds-compatibility.md)
