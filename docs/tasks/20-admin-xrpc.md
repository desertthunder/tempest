---
title: Milestone 20 - Admin XRPC Methods
specs:
  - ../specs/admin-xrpc.md
  - ../specs/admin-operations.md
  - ../specs/xrpc.md
  - ../specs/lexicon-schemas.md
---

Status: planned.

## Tasks

- [ ] Vendor `com/atproto/admin/*.json` into `priv/lexicons/official`.
- [ ] Regenerate `Tempest.Lexicon.Bundled` and confirm admin document IDs appear
      in the manifest.
- [ ] Add `auth: :admin` handling to the XRPC auth plug without changing bearer
      account-token behavior.
- [ ] Register read-only admin methods in `Tempest.Xrpc.Registry`:
      `getAccountInfo`, `getAccountInfos`, and `searchAccounts`.
- [ ] Implement read-only handlers against local account data.
- [ ] Add XRPC integration tests for missing admin token, invalid admin token,
      account token rejection, and successful admin-token requests.
- [ ] Add subject-status persistence before implementing
      `getSubjectStatus`/`updateSubjectStatus`.
- [ ] Implement invite admin methods only if invite-code persistence is present
      and matches the official response shape.
- [ ] Implement destructive account mutations last, with audit events and focused
      tests for each method.
- [ ] Add a running-server Hurl smoke test once a stable read-only endpoint
      exists.

## Verification

```bash
mix test test/tempest_web/xrpc/admin_test.exs
mix test test/tempest/lexicon
mix precommit
```

For running-server coverage:

```bash
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  test/smoke/admin-xrpc.hurl
```
