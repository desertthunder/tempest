---
title: Email Delivery
updated: 2026-06-28
---

Tempest sends transactional security email — password reset, email confirmation,
and email update — through a pluggable provider model. This page explains *why*
those flows exist and the security model behind them. For the runtime env vars,
Resend domain verification, SPF/DKIM/DMARC setup, and verification commands,
see [Deployment Guide](./deployment.md).

## Why a PDS sends transactional email

Account security on a self-hosted PDS rests on proving control of an email
address. A PDS operator is usually a single user, but the AT Protocol's account
model still requires a recoverable identity:

- **Password reset** must work without an operator on call. If the account
  password is lost, the email inbox is the only out-of-band channel that can
  prove ownership and issue a new credential.
- **Email confirmation** proves the account holder controls the address on
  file. Confirmed email gates trust decisions in the broader protocol surface.
- **Email update** changes the recovery address. Because a new address has not
  been proven yet, the token is delivered to the *target* email, not the current
  one, so the account owner cannot silently point recovery at an address they
  do not control.

Without transactional email, all three flows degrade to operator-assisted or
unverifiable state, which is unsafe for a real account.

## Token model

Tempest keeps a single `email_tokens` table for all three purposes. The model
is deliberately database-backed:

- a high-entropy raw token is generated per request;
- only a **hash** is stored — the raw token never lives at rest;
- each token is bound to one **purpose** (`confirm_email`, `update_email`, or
  `reset_password`);
- `update_email` tokens additionally bind to the **target email** they were
  issued for, so a token cannot be replayed against a different address;
- tokens carry an **expiry**;
- successful consumption marks `used_at`, making them **single-use**;
- issue and consumption emit **security events** for audit.

This is why token state belongs in the SQLite database alongside accounts, not
in blob storage: tokens are transactional, mutable, and queryable, and they must
participate in the same failure semantics as the account mutation they protect.

### Why R2 is not used for tokens

R2 (or any object store) stores blobs and backups — opaque, immutable bytes.
Email tokens need atomic issue-and-consume, expiry, and single-use enforcement,
which require database transactions and indexes. Object stores offer none of
that. Keeping tokens in the database also means a restore from backup rehydrates
token state consistently with account state.

## Security email content

Each email includes the instance name, the account handle when known,
purpose-specific action text, the token or action URL, an expiry time, and
"ignore this email" safety copy. Plain text is always present; HTML-only email
is a non-goal in the first pass so content remains deliverable across clients
and easy to audit.

## XRPC surface

The security flows are exposed through standard `com.atproto.server.*`
procedures. `requestPasswordReset` is deliberately enumeration-safe: it returns
the same success shape whether or not the identifier matches an account, so an
attacker cannot probe for existing emails, handles, or DIDs. `resetPassword`
consumes exactly one token, revokes active sessions, and updates the password
hash. `confirmEmail` and `updateEmail` accept both legacy token-only calls and
the ATProto-shaped `{email, token}` body, validating that the token's target
email matches the request.

## Failure policy

Token issuance and delivery are treated as one requested operation:

- If token insertion fails, the request returns an internal error.
- If delivery fails, the token is left unused and a temporary failure is
  returned — the token is not deleted just because the provider was unreachable.
- Provider error bodies are never exposed to clients, to avoid leaking account
  state or provider internals.

If delivery failures become common, a later milestone may add a database-backed
email queue. The first pass keeps delivery synchronous because security email
volume is low and a queue would add moving parts without changing the security
model.

## Observability

Each delivery attempt emits telemetry on `[:tempest, :email, :deliver]` with
`purpose`, `provider`, and `status` metadata. Production logs must not include
raw tokens, API keys, Authorization headers, or full provider error bodies.
Recipient-local-part detail is avoided in production logs.
