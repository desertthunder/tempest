---
title: PDS Compatibility Against Reference Surface
updated: 2026-06-02
---

# PDS Compatibility Against Reference Surface

Tempest tracks compatibility against the AT Protocol specs, the official
Lexicons, and the reference PDS implementation. This document defines the
compatibility surface that must be visible in `docs/` before Tempest is called a
usable self-hosted PDS.

The matrix is about externally observable behavior. An endpoint is not complete
until request parsing, auth, response shape, error shape, and tests are covered.
Use ConnCase for detailed endpoint checks, Hurl for running-server smoke tests,
and deployed tests for DNS, TLS, WebSockets, object storage, and relay/AppView
behavior.

## Status Keys

```text
implemented  endpoint exists and has local coverage
partial      endpoint exists but behavior, validation, or tests are incomplete
planned      endpoint is in scope but not implemented yet
deferred     endpoint is out of scope for the current target profile
```

## Endpoint Matrix

### Server and Account

| Method | Status | Required coverage |
|---|---:|---|
| `com.atproto.server.describeServer` | implemented | public metadata smoke test |
| `com.atproto.server.createAccount` | implemented | invite/account creation smoke test |
| `com.atproto.server.createSession` | implemented | login smoke test |
| `com.atproto.server.refreshSession` | implemented | refresh/revoke smoke test |
| `com.atproto.server.deleteSession` | implemented | session deletion smoke test |
| `com.atproto.server.getSession` | implemented | bearer auth smoke test |
| `com.atproto.server.createAppPassword` | implemented | app-password black-box test |
| `com.atproto.server.listAppPasswords` | implemented | app-password black-box test |
| `com.atproto.server.revokeAppPassword` | implemented | revoke black-box test |
| `com.atproto.server.getServiceAuth` | implemented | migration/service-auth smoke test |
| `com.atproto.server.checkAccountStatus` | implemented | lifecycle smoke test |
| `com.atproto.server.activateAccount` | implemented | lifecycle smoke test |
| `com.atproto.server.deactivateAccount` | implemented | lifecycle smoke test |
| `com.atproto.server.requestAccountDelete` | implemented | lifecycle smoke test |
| `com.atproto.server.deleteAccount` | implemented | lifecycle smoke test |
| `com.atproto.server.requestPasswordReset` | partial | SMTP/token flow coverage |
| `com.atproto.server.resetPassword` | partial | SMTP/token flow coverage |
| `com.atproto.server.confirmEmail` | partial | SMTP/token flow coverage |
| `com.atproto.server.requestEmailConfirmation` | partial | SMTP/token flow coverage |
| `com.atproto.server.requestEmailUpdate` | partial | SMTP/token flow coverage |
| `com.atproto.server.updateEmail` | partial | SMTP/token flow coverage |
| `com.atproto.server.reserveSigningKey` | implemented | migration smoke test |

### Identity

| Method | Status | Required coverage |
|---|---:|---|
| `com.atproto.identity.resolveHandle` | implemented | local and remote resolution smoke tests |
| `com.atproto.identity.updateHandle` | implemented | auth and DID ownership checks |
| `com.atproto.identity.getRecommendedDidCredentials` | implemented | migration smoke test |
| `com.atproto.identity.requestPlcOperationSignature` | implemented | PLC boundary tests |
| `com.atproto.identity.signPlcOperation` | implemented | PLC boundary tests |
| `com.atproto.identity.submitPlcOperation` | implemented | PLC boundary tests |

### Repository

| Method | Status | Required coverage |
|---|---:|---|
| `com.atproto.repo.createRecord` | implemented | record smoke test |
| `com.atproto.repo.putRecord` | implemented | swap and validation tests |
| `com.atproto.repo.deleteRecord` | implemented | delete and tombstone tests |
| `com.atproto.repo.applyWrites` | implemented | batch write smoke test |
| `com.atproto.repo.getRecord` | implemented | record read smoke test |
| `com.atproto.repo.listRecords` | implemented | pagination smoke test |
| `com.atproto.repo.describeRepo` | implemented | repo metadata test |
| `com.atproto.repo.uploadBlob` | implemented | blob smoke test |
| `com.atproto.repo.listMissingBlobs` | implemented | migration/blob smoke test |
| `com.atproto.repo.importRepo` | implemented | import rejection and restore tests |

### Sync

| Method | Status | Required coverage |
|---|---:|---|
| `com.atproto.sync.getRepo` | implemented | CAR export and verification test |
| `com.atproto.sync.getBlocks` | implemented | block CAR smoke test |
| `com.atproto.sync.getRecord` | implemented | block-level record smoke test |
| `com.atproto.sync.getLatestCommit` | implemented | commit metadata test |
| `com.atproto.sync.getRepoStatus` | implemented | active/deactivated states |
| `com.atproto.sync.listRepos` | implemented | pagination smoke test |
| `com.atproto.sync.listBlobs` | implemented | blob listing smoke test |
| `com.atproto.sync.getBlob` | implemented | local and S3/R2 adapter tests |
| `com.atproto.sync.requestCrawl` | implemented | local test plus deployed relay check |
| `com.atproto.sync.subscribeRepos` | implemented | WebSocket backfill/live smoke test |
| `com.atproto.sync.notifyOfUpdate` | deferred | not required for current target profile |

### AppView and Compatibility Helpers

| Method | Status | Required coverage |
|---|---:|---|
| `app.bsky.actor.getPreferences` | implemented | preference smoke test |
| `app.bsky.actor.putPreferences` | implemented | preference smoke test |
| Unknown `app.bsky.*` methods | partial | explicit proxy/fallback policy |

## Non-endpoint Compatibility

- OAuth metadata, PAR, token exchange, DPoP, and revoke behavior must have
  black-box tests.
- App passwords must work with clients that still use legacy auth.
- Hosted DID documents and handle verification must pass from outside the host.
- Firehose frames must match the AT Protocol sync framing and commit event shape.
- CAR exports must be repeatable and verifiable after restore.
- Blob lifecycle must cover temporary uploads, record references, public reads,
  garbage collection, and S3/R2-backed storage.
- Migration tests must cover import, activation, deactivation, service auth, and
  missing blobs.

## Verification

Local compatibility:

```bash
mix test
hurl --test --jobs 1 --variable base_url=http://localhost:4000 test/smoke/
```

ConnCase should cover detailed request/response/auth/error behavior. Hurl should
cover milestone-level flows through a running server.

Deployed compatibility:

```bash
hurl --test --jobs 1 \
  --variable base_url=https://tempest.example.com \
  --variable admin_token="$ADMIN_TOKEN" \
  test/smoke/deployment.hurl
```

## Sources

- <https://github.com/bluesky-social/atproto/tree/main/lexicons>
- <https://github.com/bluesky-social/atproto/tree/main/packages/pds>
- <https://github.com/bluesky-social/pds>
- <https://atproto.com/specs/xrpc>
- <https://atproto.com/specs/repository>
- <https://atproto.com/specs/sync>
- <https://atproto.com/specs/oauth>
- <https://atproto.com/guides/account-migration>
