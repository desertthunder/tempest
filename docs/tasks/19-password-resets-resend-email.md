---
title: Milestone 19 - Password Resets and Resend Email Delivery
specs:
  - ../specs/password-resets-resend-email.md
  - ../specs/accounts-auth.md
  - ../specs/security-oauth.md
  - ../specs/deployment-observability.md
references:
  - ../reference/security-oauth.md
  - ../reference/deployment.md
---

Goal: make password reset, email confirmation, and email update flows production
usable on Railway with Resend, while keeping token state in the database and R2
limited to blobs and backups.

## Configuration

- [ ] T19-01: Add `TEMPEST_EMAIL_PROVIDER` runtime config with `local`, `smtp`,
      and `resend` values.
- [ ] T19-02: Add Resend runtime config for `TEMPEST_RESEND_API_KEY`,
      `TEMPEST_EMAIL_FROM_NAME`, and `TEMPEST_EMAIL_FROM_ADDRESS`.
- [ ] T19-03: Configure `Swoosh.Adapters.Resend` when
      `TEMPEST_EMAIL_PROVIDER=resend`.
- [ ] T19-04: Keep SMTP support as a fallback provider and map existing
      `TEMPEST_SMTP_*` variables to the new shared `TEMPEST_EMAIL_FROM_*`
      values where possible.
- [ ] T19-05: Fail closed during production boot when `resend` or `smtp` is
      selected without the required credentials or from address.
- [ ] T19-06: Add documentation for Railway env vars, Resend domain
      verification, SPF, DKIM, and DMARC expectations.

## Email Delivery

- [ ] T19-07: Update `Tempest.Security.Email` so provider metadata is attached
      to `[:tempest, :email, :deliver]` telemetry.
- [ ] T19-08: Add text email builders for password reset, email confirmation,
      and email update with handle, purpose, expiry, and ignore-this-email copy.
- [ ] T19-09: Add provider options for Resend tags and idempotency keys when the
      Resend adapter is active.
- [ ] T19-10: Ensure production logs do not include raw tokens, Resend API keys,
      auth headers, or full provider error bodies.
- [ ] T19-11: Add tests for successful Resend adapter config without making a
      network call.
- [ ] T19-12: Add tests for missing Resend API key/from address config.

## XRPC Shape

- [ ] T19-13: Keep `requestPasswordReset` enumeration-safe for unknown email,
      handle, or DID values.
- [ ] T19-14: Verify `resetPassword` consumes one token, rejects reuse, validates
      password strength, revokes sessions, and allows login with the new
      password.
- [ ] T19-15: Update `requestEmailUpdate` to return
      `{"tokenRequired": true}` when a token is required.
- [ ] T19-16: Update `updateEmail` to accept `{email, token}` and verify the
      token target email matches the requested email.
- [ ] T19-17: Update `confirmEmail` to accept both token-only calls and
      ATProto-shaped `{email, token}` calls.
- [ ] T19-18: Add explicit tests for invalid, expired, reused, wrong-purpose,
      and wrong-target-email tokens.

## Browser Follow-through

- [ ] T19-19: Add minimal browser pages for entering reset, confirmation, and
      update tokens if the account Control Panel work has not provided them yet.
- [ ] T19-20: Generate action URLs in email bodies when `PHX_HOST` is configured;
      otherwise fall back to plain token copy.
- [ ] T19-21: Add route and form tests using stable element IDs for the browser
      token-entry pages.

## Deployment Verification

- [ ] T19-22: Add `test/smoke/email-security.hurl` for deployed password-reset
      request and token consumption using an operator-supplied token.
- [ ] T19-23: Add a Railway deployment checklist covering Resend env vars,
      verified sending domain, DNS records, and test inbox verification.
- [ ] T19-24: Add an admin/operator note explaining that R2 is not used for
      account email tokens.
- [ ] T19-25: Run `mix precommit` after implementation and fix all pending
      issues.

## Integration Tests

- Resend provider config selects `Swoosh.Adapters.Resend`.
- SMTP provider config still selects `Swoosh.Adapters.SMTP`.
- Missing production email credentials fail clearly.
- Password reset request for an unknown identifier returns success-shaped output.
- Password reset email includes no raw database token hash.
- Password reset token is single-use.
- Password reset revokes existing sessions.
- Email confirmation accepts `{email, token}` and rejects a mismatched email.
- Email update accepts `{email, token}` and rejects a token issued for a
  different target email.
- Email delivery telemetry includes purpose, provider, and status.
- Production logs redact provider secrets and raw tokens.

## HTTP Verification

```bash
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  --variable account_email="email-security-$(date +%s)@example.com" \
  test/smoke/email-security.hurl
```

For deployed Railway verification, run against the public HTTPS host after
Resend DNS verification is complete:

```bash
hurl --test --jobs 1 \
  --variable base_url=https://tempest.example.com \
  --variable account_email=reset-target@example.com \
  test/smoke/email-security.hurl
```

## Implementation Notes

Keep the first version synchronous. Password reset and confirmation volume is
low, and adding a queue before delivery failures are observed would add moving
parts without changing the security model.

Use the database for token state. Do not introduce R2 reads or writes for email
tokens.

Prefer Swoosh Resend API delivery over SMTP for production because the current
Phoenix production config already uses `Swoosh.ApiClient.Req`, and the Resend
adapter supports provider tags and idempotency keys. Keep SMTP documented as a
fallback because it is already supported by Tempest and Resend.
