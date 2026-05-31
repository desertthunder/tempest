# CHANGELOG

## v0.1.0

### 2026-05-31

- Added compatibility smoke coverage for `applyWrites`, `getBlocks`, `requestCrawl`,
  preference endpoints, and unknown AppView fallback.
- Added account security foundations for email tokens, security events, TOTP MFA,
  backup codes, delegated-access grants, session revocation, and auth rate limits.
- Added hosted DID mode configuration, PLC publish boundary, and identity correctness
  smoke coverage.
- Added migration lifecycle support for service auth, imported DID account creation,
  repo CAR import, missing-blob listing, activation/deactivation, account deletion,
  migration-safe event ordering, and smoke coverage.

### 2026-05-08

- Added pure-Elixir repository primitives for AT URIs, NSIDs, record keys, DIDs, TIDs,
  CIDs, DRISL CBOR, CAR v1, MST operations, and signed commits.
- Added per-account repository storage with blocks, records, commits, and repo metadata.
- Initialized an empty repository when creating an account.
- Added record writes and reads through `com.atproto.repo.createRecord`,
  `putRecord`, `deleteRecord`, `getRecord`, `listRecords`, and `describeRepo`.
- Added record validation boundaries, duplicate-rkey handling, swap checks, pagination,
  and restart persistence coverage.
- Added sync read support for `getRepo`, `getLatestCommit`, `getRecord`, `getBlocks`,
  `getRepoStatus`, `listRepos`, and `listBlobs`.
- Set CAR responses to `Content-Type: application/vnd.ipld.car`.

### 2026-05-07

- Added the home page with a compact "unix appliance" style.
- Added `Tempest.Config` with hostname and data-directory validation.
- Added `/xrpc/_health` and `com.atproto.server.describeServer`.
- Added the XRPC router pipeline, method registry, protocol-shaped JSON errors, and verb
  mismatch handling.
- Added SQLite account storage, password hashing, access/refresh tokens, session
  endpoints, and bearer auth.
- Added DID and handle validators, signing keys, DID document generation, hosted
  DID discovery, handle resolution, handle update, and SSRF protection for remote handle
  checks.
- Added Hurl smoke test scaffolding.
