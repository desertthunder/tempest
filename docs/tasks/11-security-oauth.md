---
title: Milestone 11 - Security, OAuth, and Delegated Access
specs:
  - ../specs/security-oauth.md
  - ../specs/accounts-auth.md
---

Goal: make Tempest usable by modern atproto clients without weakening account security.

## Tasks

- [x] T11-01: Add OAuth metadata endpoints for protected resource and authorization server.
- [x] T11-02: Add OAuth JWKS management and key rotation plan.
- [x] T11-03: Add hardened external metadata fetcher with SSRF protections, body limits, and timeouts.
- [x] T11-04: Implement DPoP nonce generation and verification.
- [x] T11-05: Implement PAR storage and validation.
- [x] T11-06: Implement authorization UI with conservative unknown-client display.
- [x] T11-07: Implement token endpoint with PKCE, DPoP binding, refresh, and revocation.
- [x] T11-08: Add centralized permission engine used by OAuth, app passwords, and delegated access.
- [x] T11-09: Implement current transition scopes and `blob:*/*`/`rpc:*` enforcement.
- [x] T11-10: Implement app password create/list/revoke endpoints with scoped permissions.
- [ ] T11-11: Add email confirmation/update and password reset security log events.
- [ ] T11-12: Add MFA schema for TOTP, passkeys/WebAuthn, backup codes, and trusted devices.
- [ ] T11-13: Implement TOTP and backup-code flows.
- [ ] T11-14: Add session inventory and remote revoke.
- [ ] T11-15: Add delegated-access schema and revoke flow.
- [ ] T11-16: Add auth, reset, OAuth, and app-password rate limits.
- [ ] T11-17: Add Hurl smoke tests for OAuth metadata, PAR nonce, token issue, scope enforcement, and revoke.

## Integration Tests

- OAuth client can complete an authorization-code flow.
- DPoP-bound tokens fail without valid DPoP proof.
- Partial scopes are enforced exactly.
- App passwords cannot perform account-management actions.
- Revoked OAuth/app-password/delegation credentials fail on the next request.

## HTTP Verification

```bash
hurl --test --jobs 1 --variable base_url=http://localhost:4000 test/smoke/oauth-security.hurl
```
