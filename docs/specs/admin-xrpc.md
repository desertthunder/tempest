---
title: Admin XRPC Methods
updated: 2026-06-19
status: planned
---

Tempest already has Phoenix operator pages and internal admin helpers. This
spec covers a separate compatibility layer for the official
`com.atproto.admin.*` XRPC namespace after those Lexicons are vendored.

## Goals

- Vendor the official `com.atproto.admin.*` Lexicons from
  `bluesky-social/atproto` at the same pinned revision as the rest of
  `priv/lexicons/official`.
- Expose admin XRPC methods only behind the existing admin-token trust boundary.
- Prefer read-only account inspection first, then status and invite controls,
  then destructive account mutation only after audit logging and tests are in
  place.
- Keep operator UI behavior and XRPC admin behavior backed by the same domain
  functions where practical.

## Non-goals

- Do not make account bearer tokens valid for `com.atproto.admin.*`.
- Do not treat vendored Lexicons as automatic behavior. Registration and handler
  implementation remain explicit.
- Do not implement destructive methods without audit events and integration
  coverage.

## Lexicons

The official admin namespace currently contains these method documents:

- `com.atproto.admin.getAccountInfo`
- `com.atproto.admin.getAccountInfos`
- `com.atproto.admin.searchAccounts`
- `com.atproto.admin.deleteAccount`
- `com.atproto.admin.updateAccountEmail`
- `com.atproto.admin.updateAccountHandle`
- `com.atproto.admin.updateAccountPassword`
- `com.atproto.admin.updateAccountSigningKey`
- `com.atproto.admin.getInviteCodes`
- `com.atproto.admin.disableInviteCodes`
- `com.atproto.admin.disableAccountInvites`
- `com.atproto.admin.enableAccountInvites`
- `com.atproto.admin.getSubjectStatus`
- `com.atproto.admin.updateSubjectStatus`
- `com.atproto.admin.sendEmail`
- `com.atproto.admin.defs`

Required dependencies include existing `com.atproto.repo.strongRef` and
`com.atproto.server.defs#inviteCode`.

## Auth

Register admin methods with `auth: :admin` in `Tempest.Xrpc.Registry`.
`TempestWeb.Plugs.XrpcAuth` currently handles bearer account auth only, so it
needs an admin branch that verifies `Authorization: Bearer <admin-token>` with
`Tempest.AdminAuth.verify_authorization_header/1`.

Admin failures should return normal XRPC JSON errors:

- missing token: `401 AuthenticationRequired`
- invalid token: `401 InvalidToken`
- admin token not configured: `503 ServiceUnavailable` or `403 Forbidden`

The exact unconfigured status should be decided once the handler branch is
implemented. The important property is that admin methods never silently fall
back to account auth.

## Initial Method Set

Start with read-only methods:

- `getAccountInfo`: find one local account by DID and return
  `com.atproto.admin.defs#accountView`.
- `getAccountInfos`: return the same shape for a list of DIDs.
- `searchAccounts`: support email search first, then add handle/DID search if
  the official shape remains compatible.

Next implement status and invite controls:

- `getSubjectStatus` and `updateSubjectStatus` for repo/account subjects first.
- Blob and record subject status after a small persistence model exists.
- `getInviteCodes`, `disableInviteCodes`, `disableAccountInvites`, and
  `enableAccountInvites` only if Tempest keeps invite-code state compatible
  with `com.atproto.server.defs#inviteCode`.

Leave destructive account mutation last:

- `deleteAccount`
- `updateAccountEmail`
- `updateAccountHandle`
- `updateAccountPassword`
- `updateAccountSigningKey`
- `sendEmail`

## Persistence

Account-level deactivation already exists in account state. Takedown and
subject-status support needs explicit persistence if it should apply to records
and blobs. A simple first model is:

- subject kind: `account`, `record`, or `blob`
- DID
- optional record URI
- optional CID
- takedown applied flag and reference string
- deactivated applied flag and reference string
- timestamps and actor metadata for audit

Use this model to drive both admin XRPC responses and any future operator UI.

## Verification

Required tests before marking implemented:

```bash
mix test test/tempest_web/xrpc/admin_test.exs
mix test test/tempest/lexicon
mix precommit
```

Add a Hurl smoke test once at least one read-only method is exposed through a
running server:

```bash
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  test/smoke/admin-xrpc.hurl
```
