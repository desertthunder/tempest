# CHANGELOG

## v0.1.0

### 2026-06-15

- Added OAuth client metadata validation for the public-client path

### 2026-06-13

- Added deployment verification support for post-deployment checks, including release
  and deployment docs, HTTPS smoke runbook, and hosted DID/relay/AppView verification
  guidance.
- Added public aggregate stats surfaces:
  - `GET /stats` HTML dashboard.
  - `GET /xrpc/_stats` public JSON snapshot with generated timestamps.
  - Public stats privacy checks and smoke coverage for unauthorized-sensitive data.

### 2026-06-12

- Added local PDS compatibility verification for protocol endpoints, auth matrices,
  black-box flows, and event compatibility against local smoke profiles.
- Added restore-drill coverage and local AppView proxy/fallback verification to keep
  compatibility expectations aligned before deployment.

### 2026-06-03

- Added authenticated account operator UI for repo/blob browsing, sequencer and
  firehose inspection, access credentials, security state, and migration status.
- Added admin operator UI for service status, account status, storage, repo
  verify/export/import actions, backup create/restore dry-run, and compatibility
  status.

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
- Added baseline identity and handle local behavior for did:web and did:plc setup.
- Added hosted DID mode config, public DID publishing, and handle verification flow checks.
