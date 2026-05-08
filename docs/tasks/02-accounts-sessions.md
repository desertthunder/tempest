---
title: Milestone 02 - Accounts and Sessions
specs:
  - ../specs/storage-sqlite.md
  - ../specs/accounts-auth.md
---

Goal: create local accounts and authenticate XRPC calls.

## Tasks

- [x] T02-01: Replace Postgres dependency/config with SQLite-first config if still present.
- [x] T02-02: Add migrations or bootstrap code for `account.sqlite`.
- [x] T02-03: Add `accounts` table and schema/context.
- [x] T02-04: Add password hashing dependency and wrapper.
- [x] T02-05: Implement account creation with validation.
- [x] T02-06: Add refresh token table and hashed storage.
- [x] T02-07: Add access token signing and verification.
- [x] T02-08: Implement `createSession`.
- [x] T02-09: Implement `refreshSession` with token rotation.
- [x] T02-10: Implement `deleteSession`.
- [x] T02-11: Implement `getSession`.
- [x] T02-12: Add bearer auth plug and auth context assign.
- [x] T02-13: Add integration tests for create, login, refresh, delete.
- [x] T02-14: Add failure tests for wrong password and reused refresh token.

## Integration Tests

- Account creation persists across process restart.
- Session login returns access and refresh tokens.
- Deleted session can no longer refresh.
- Protected endpoint rejects missing bearer token.

## HTTP Verification

```bash
suffix="$(date +%s)"
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  --variable account_handle="smoke-${suffix}.test" \
  --variable account_email="smoke-${suffix}@example.com" \
  --variable account_password="correct horse battery staple" \
  test/smoke/accounts.hurl
```

## Done

Run:

```bash
mix precommit
```
