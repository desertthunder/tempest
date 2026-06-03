---
title: Security, OAuth, and Delegated Access
updated: 2026-06-03
status: implemented
---

Reference documentation: ../reference/security-oauth.md

Verification:

```bash
mix test test/tempest/security_test.exs \
  test/tempest_web/controllers/oauth_flow_test.exs

hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  test/smoke/oauth-security.hurl
```
