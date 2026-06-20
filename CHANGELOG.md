# CHANGELOG

## v0.1.0

### 2026-06-15

- Added OAuth client metadata validation for the public-client path

### 2026-06-14

- Expanded the public stats dashboard with user cards, profile image blobs,
  latest indexed record details, weekly commit activity, and collection
  summaries.
- Added the `/changelog` pageoute for `CHANGELOG.md` rendering and a desktop shortcut.
- Added the `/docs`/reference viewer with Markdown rendering, safe manifest lookup,
  relative reference-link rewriting, and a retro browser-style interface.

### 2026-06-13

- Added deployment support for release builds, deployment docs, HTTPS operations,
  and hosted DID, relay, and AppView readiness.
- Added public aggregate stats surfaces:
  - `GET /stats` HTML dashboard.
  - `GET /xrpc/_stats` public JSON snapshot with generated timestamps.

### 2026-06-12

- Added local PDS compatibility support for protocol endpoints, auth matrices,
  public HTTP flows, and event compatibility.
- Added restore drills and a local AppView proxy/fallback policy to keep
  compatibility behavior aligned before deployment.

### 2026-06-03

- Added authenticated account operator UI for repo/blob browsing, sequencer and
  firehose inspection, access credentials, security state, and migration status.
- Added admin operator UI for service status, account status, storage, repo
  verify/export/import actions, backup create/restore dry-run, and compatibility
  status.

### 2026-05-31

- Added compatibility behavior for `applyWrites`, `getBlocks`, `requestCrawl`,
  preference endpoints, and unknown AppView fallback.
- Added account security foundations for email tokens, security events, TOTP MFA,
  backup codes, delegated-access grants, session revocation, and auth rate limits.
- Added hosted DID mode configuration, PLC publish boundary, and identity correctness
  protections.
- Added migration lifecycle support for service auth, imported DID account creation,
  repo CAR import, missing-blob listing, activation/deactivation, account deletion,
  and migration-safe event ordering.

### 2026-05-08

- Added pure-Elixir repository primitives for AT URIs, NSIDs, record keys, DIDs, TIDs,
  CIDs, DRISL CBOR, CAR v1, MST operations, and signed commits.
- Added per-account repository storage with blocks, records, commits, and repo metadata.
- Initialized an empty repository when creating an account.
- Added record writes and reads through `com.atproto.repo.createRecord`,
  `putRecord`, `deleteRecord`, `getRecord`, `listRecords`, and `describeRepo`.
- Added record validation boundaries, duplicate-rkey handling, swap handling,
  pagination, and restart persistence.
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
  resolution.
- Added Hurl-based compatibility tooling.
- Added baseline identity and handle local behavior for did:web and did:plc setup.
- Added hosted DID mode config, public DID publishing, and handle verification flows.
