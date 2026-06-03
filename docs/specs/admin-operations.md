---
title: Admin Operations
updated: 2026-06-03
status: implemented
---

Reference documentation: ../reference/admin-operations.md

Verification:

```bash
mix test test/tempest_web/controllers/admin_controller_test.exs \
  test/tempest_web/controllers/operator_account_controller_test.exs

hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  --variable suffix="$(date +%s)" \
  test/smoke/operator-account-ux.hurl
```
