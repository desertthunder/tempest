---
title: Accounts and Auth
updated: 2026-05-07
---

# Accounts and Auth

Accounts provide the local login and hosting state for a DID. Identity is separate: a DID can exist outside this PDS, and hosted content should follow account state.

## Account States

Store `active` as a boolean and `status` as a string. Known statuses:

```text
active
deactivated
deleted
takendown
suspended
desynchronized
throttled
```

`active=false` means Tempest must not redistribute repo content or blobs for the account.

## Session Auth

Implement first:

```text
com.atproto.server.createAccount
com.atproto.server.createSession
com.atproto.server.refreshSession
com.atproto.server.deleteSession
com.atproto.server.getSession
```

Session design:

- Hash passwords with a password hashing library such as `argon2_elixir`.
- Store refresh token hashes, not refresh tokens.
- Access tokens should be short lived.
- Refresh must rotate refresh tokens.
- App passwords are separate credentials with limited intended use.

OAuth is required for stronger long-term compatibility, but it should follow repo and sync correctness.

## Account Creation

Account creation must:

1. Validate handle and email input.
2. Create or confirm DID identity.
3. Create signing key material.
4. Initialize an empty repository.
5. Insert account row.
6. Emit identity/account/commit events in the sequencer.

The recommended account creation event order is identity, account, commit.

## Auth Plug

The XRPC auth plug should:

- Parse `Authorization: Bearer <token>`.
- Validate token signature and expiry.
- Resolve the account.
- Reject inactive accounts for writes.
- Assign a clear auth context for handlers.

## Adversarial Checks

- `String.to_atom/1` must not be used on user input.
- Refresh token reuse should revoke the session family.
- Disabled accounts must not write records.
- App password names are not passwords and must not be returned as credentials.
- Session responses must not expose password hashes or refresh token hashes.

## HTTP Verification

```bash
http POST :4000/xrpc/com.atproto.server.createAccount \
  handle=alice.test password='correct horse battery staple' email=alice@example.com

http POST :4000/xrpc/com.atproto.server.createSession \
  identifier=alice.test password='correct horse battery staple'

TOKEN="$(http --body POST :4000/xrpc/com.atproto.server.createSession \
  identifier=alice.test password='correct horse battery staple' | jq -r .accessJwt)"

http GET :4000/xrpc/com.atproto.server.getSession "Authorization:Bearer $TOKEN"
```

Expected:

- Account creation returns DID, handle, access token, and refresh token.
- Session creation returns a usable bearer token.
- Authenticated `getSession` returns the current account.

## Sources

- <https://atproto.com/specs/account>
- <https://atproto.com/guides/account-lifecycle>
- <https://github.com/bluesky-social/atproto/tree/main/lexicons/com/atproto/server>
