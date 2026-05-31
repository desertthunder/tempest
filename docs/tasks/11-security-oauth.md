---
title: Milestone 11 - Security, OAuth, and Delegated Access
specs:
  - ../specs/security-oauth.md
  - ../specs/accounts-auth.md
  - ../specs/identity-handles.md
---

Completed [May 31, 2026](../../CHANGELOG.md#2026-05-31).

## Verification

```bash
mix test
hurl --test --jobs 1 --variable base_url=http://localhost:4000 test/smoke/oauth-security.hurl
hurl --test --jobs 1 --variable base_url=http://localhost:4000 test/smoke/identity-correctness.hurl
```

The smoke tests verify OAuth metadata, PAR/token/revoke error paths, identity
correctness, and hosted handle resolution. ExUnit covers OAuth authorization-code
flow, DPoP token issue/revoke, email tokens, security events, TOTP MFA, backup
codes, session revocation, delegated-access grants, and rate limiting.
