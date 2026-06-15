---
title: Password Resets and Resend Email Delivery
updated: 2026-06-15
status: planned
---

Tempest should provide production-ready email delivery for account security
flows using Resend, while keeping the reset and confirmation state in the
application database.

R2 stores blobs and backups. Password-reset and email-confirmation flows need
transactional token creation, single-use token consumption, expiry checks,
account mutation, session revocation, and audit events. Those belong in the
database.

## Source Baseline

Research checked on 2026-06-15:

- Resend SMTP documentation: <https://resend.com/docs/send-with-smtp>
- Swoosh Resend adapter documentation:
  <https://hexdocs.pm/swoosh/Swoosh.Adapters.Resend.html>
- Current Tempest implementation:
  `lib/tempest/security.ex`
- Current Tempest email helper:
  `lib/tempest/security/email.ex`

## Goals

- Send password reset, email confirmation, and email update messages through
  Resend in production.
- Keep local dev and tests on Swoosh local/test adapters.
- Prefer the Swoosh Resend API adapter for production Resend delivery.
- Keep SMTP as a documented fallback because Resend also supports SMTP.
- Keep raw reset and confirmation tokens out of the database.
- Preserve single-use tokens, expiry, account-scoped audit events, and session
  revocation on password reset.
- Make production email configuration explicit and easy to validate on Railway.
- Add smoke coverage that proves a deployed node can request and consume account
  security tokens without exposing secrets in logs or responses.

## Non-goals

- No email queue in the first pass.
- No marketing, newsletter, broadcast, inbound email, or webhook processing.
- No Resend templates in the first pass.
- No R2 token storage.
- No provider-specific code in XRPC handlers.
- No HTML-only emails. Plain text must always exist.

## Provider Model

Tempest should support a small provider switch:

```text
TEMPEST_EMAIL_PROVIDER=local | smtp | resend
```

The default remains local outside production unless explicitly configured.

### Resend API

The preferred production provider is Resend via `Swoosh.Adapters.Resend`.
Production config should read:

```text
TEMPEST_EMAIL_PROVIDER=resend
TEMPEST_RESEND_API_KEY=...
TEMPEST_EMAIL_FROM_NAME=Tempest
TEMPEST_EMAIL_FROM_ADDRESS=no-reply@example.com
```

`config/prod.exs` already configures `Swoosh.ApiClient.Req`, which satisfies the
Resend adapter's API-client requirement. The runtime config should fail closed
in production if `TEMPEST_EMAIL_PROVIDER=resend` is selected without an API key
or from address.

### Resend SMTP Fallback

SMTP can remain available for environments where API delivery is not desired:

```text
TEMPEST_EMAIL_PROVIDER=smtp
TEMPEST_SMTP_HOST=smtp.resend.com
TEMPEST_SMTP_PORT=587
TEMPEST_SMTP_USERNAME=resend
TEMPEST_SMTP_PASSWORD=<resend_api_key>
TEMPEST_SMTP_SSL=false
TEMPEST_SMTP_TLS=always
TEMPEST_SMTP_AUTH=always
TEMPEST_EMAIL_FROM_NAME=Tempest
TEMPEST_EMAIL_FROM_ADDRESS=no-reply@example.com
```

Do not keep separate `TEMPEST_SMTP_FROM_*` and Resend from-address variables in
the long term. Prefer shared `TEMPEST_EMAIL_FROM_*` names and keep the older
SMTP names only as backwards-compatible aliases.

## Token Model

Tempest should keep the current `email_tokens` model:

- generate a high-entropy raw token;
- store only a hash;
- bind the token to one purpose;
- bind update-email tokens to the target email;
- set an expiry;
- mark successful consumption with `used_at`;
- log token issue and consumption events.

Supported purposes:

```text
confirm_email
update_email
reset_password
```

Password reset must revoke active sessions before accepting the new password.

## XRPC Behavior

### requestPasswordReset

`com.atproto.server.requestPasswordReset` accepts an email, handle, or DID. The
response should not reveal whether an account exists.

If an account exists, Tempest issues a `reset_password` token and sends a Resend
email to the account's current email address.

### resetPassword

`com.atproto.server.resetPassword` accepts a token and new password. On success,
Tempest consumes the token, revokes active sessions, updates the password hash,
and returns `{}`.

Invalid, expired, or already-used tokens should return protocol-shaped errors
without identifying the account.

### requestEmailConfirmation

`com.atproto.server.requestEmailConfirmation` requires authenticated account
access. It sends a `confirm_email` token to the account's current email address.

The first pass may continue to send even if the email is already confirmed, but
the preferred behavior is to return `{}` without issuing a new token when the
email is already confirmed.

### confirmEmail

`com.atproto.server.confirmEmail` should accept both current Tempest token-only
calls and the ATProto-shaped `{email, token}` body. When `email` is present, it
must match the account email associated with the token.

### requestEmailUpdate

`com.atproto.server.requestEmailUpdate` requires authenticated account access and
a target `email`. It sends an `update_email` token to the target email address.

The response should match the protocol shape:

```json
{ "tokenRequired": true }
```

If Tempest later distinguishes unconfirmed accounts, an unconfirmed existing
email may return `{"tokenRequired": false}` and allow direct update. Until that
policy is explicit, require the token.

### updateEmail

`com.atproto.server.updateEmail` should accept `{email, token}`. The token must
be an `update_email` token whose stored target email matches the requested email.
On success, update the account email and clear confirmed-email state unless the
flow explicitly verifies the new address in the same transaction.

## Email Content

Each email should include:

- product/instance name;
- account handle when known;
- purpose-specific action text;
- token or action URL;
- expiry time;
- "ignore this email" safety copy;
- plain text body.

Action URLs are preferred once browser pages exist:

```text
https://<public-host>/account/password/reset?token=...
https://<public-host>/account/email/confirm?token=...
https://<public-host>/account/email/update?token=...
```

Until those pages exist, plain tokens are acceptable.

## Railway Configuration

Railway should provide:

```text
PHX_HOST=<public host>
TEMPEST_EMAIL_PROVIDER=resend
TEMPEST_RESEND_API_KEY=...
TEMPEST_EMAIL_FROM_NAME=Tempest
TEMPEST_EMAIL_FROM_ADDRESS=no-reply@<verified domain>
```

The Resend sending domain must be verified before production testing. SPF, DKIM,
and DMARC should be configured at DNS before relying on password reset emails.

## Observability

Tempest should emit telemetry for each delivery attempt:

```text
[:tempest, :email, :deliver]
```

Metadata should include:

- `purpose`
- `provider`
- `status`

Do not include raw tokens, API keys, auth headers, or recipient-local-part detail
in logs. Full recipient addresses may appear in Swoosh structs during tests, but
production logs should avoid them.

## Failure Policy

Token issuance and delivery should be treated as one requested operation:

- If token insertion fails, return an internal error.
- If Resend delivery fails, return a temporary failure and leave the token
  unused.
- Do not delete a token only because delivery failed in the first pass.
- Do not expose provider error bodies to clients.

If delivery failures become common, add a database-backed email queue in a later
milestone.

## Verification

Local verification:

```bash
mix test test/tempest/security_test.exs test/tempest_web/xrpc/email_flows_test.exs
```

Production-style local verification with Resend config:

```bash
TEMPEST_EMAIL_PROVIDER=resend \
TEMPEST_RESEND_API_KEY="$TEMPEST_RESEND_API_KEY" \
TEMPEST_EMAIL_FROM_ADDRESS="$TEMPEST_EMAIL_FROM_ADDRESS" \
mix test test/tempest/security/email_delivery_config_test.exs
```

Deployed smoke verification:

```bash
hurl --test --jobs 1 \
  --variable base_url=https://tempest.example.com \
  --variable account_email=reset-target@example.com \
  test/smoke/email-security.hurl
```
