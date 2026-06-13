---
title: PDS Compatibility Matrix
updated: 2026-06-13
---

Tempest tracks compatibility against the AT Protocol specs, the official
Lexicons, and the reference PDS. The implemented rows below must be backed by a
registered XRPC handler and a bundled Lexicon document generated from
`bluesky-social/atproto` commit `22de65eea4c5573480b3a3755db1ece3db75ae18`.
An endpoint is complete only when request parsing, auth, response shape, error
shape, and tests are covered.

Status keys:

```text
implemented  endpoint exists and has local coverage
partial      endpoint exists but behavior, validation, or tests are incomplete
planned      endpoint is in scope but not implemented yet
deferred     endpoint is out of scope for the current target profile
```

## Server and account

| Method                                        |      Status | Required coverage                  |
| --------------------------------------------- | ----------: | ---------------------------------- |
| `com.atproto.server.describeServer`           | implemented | public metadata smoke test         |
| `com.atproto.server.createAccount`            | implemented | invite/account creation smoke test |
| `com.atproto.server.createSession`            | implemented | login smoke test                   |
| `com.atproto.server.refreshSession`           | implemented | refresh/revoke smoke test          |
| `com.atproto.server.deleteSession`            | implemented | session deletion smoke test        |
| `com.atproto.server.getSession`               | implemented | bearer auth smoke test             |
| `com.atproto.server.createAppPassword`        | implemented | app-password black-box test        |
| `com.atproto.server.listAppPasswords`         | implemented | app-password black-box test        |
| `com.atproto.server.revokeAppPassword`        | implemented | revoke black-box test              |
| `com.atproto.server.getServiceAuth`           | implemented | migration/service-auth smoke test  |
| `com.atproto.server.checkAccountStatus`       | implemented | lifecycle smoke test               |
| `com.atproto.server.activateAccount`          | implemented | lifecycle smoke test               |
| `com.atproto.server.deactivateAccount`        | implemented | lifecycle smoke test               |
| `com.atproto.server.requestAccountDelete`     | implemented | lifecycle smoke test               |
| `com.atproto.server.deleteAccount`            | implemented | lifecycle smoke test               |
| `com.atproto.server.requestPasswordReset`     |     partial | SMTP/token flow coverage           |
| `com.atproto.server.resetPassword`            |     partial | SMTP/token flow coverage           |
| `com.atproto.server.confirmEmail`             |     partial | SMTP/token flow coverage           |
| `com.atproto.server.requestEmailConfirmation` |     partial | SMTP/token flow coverage           |
| `com.atproto.server.requestEmailUpdate`       |     partial | SMTP/token flow coverage           |
| `com.atproto.server.updateEmail`              |     partial | SMTP/token flow coverage           |
| `com.atproto.server.reserveSigningKey`        | implemented | migration smoke test               |

## Identity

| Method                                              |      Status | Required coverage                                            |
| --------------------------------------------------- | ----------: | ------------------------------------------------------------ |
| `com.atproto.identity.resolveHandle`                | implemented | local and remote resolution smoke tests                      |
| `com.atproto.identity.updateHandle`                 | implemented | auth and DID ownership checks                                |
| `com.atproto.identity.getRecommendedDidCredentials` | implemented | credential shape, auth, dedicated PLC rotation key tests     |
| `com.atproto.identity.requestPlcOperationSignature` | implemented | strong reauth, single-use token, audit-log tests             |
| `com.atproto.identity.signPlcOperation`             | implemented | token consumption, fake PLC prev fetch, validation tests     |
| `com.atproto.identity.submitPlcOperation`           | implemented | fake PLC submission, failure, idempotency, event-order tests |

## Repository

| Method                              |      Status | Required coverage                  |
| ----------------------------------- | ----------: | ---------------------------------- |
| `com.atproto.repo.createRecord`     | implemented | record smoke test                  |
| `com.atproto.repo.putRecord`        | implemented | swap and validation tests          |
| `com.atproto.repo.deleteRecord`     | implemented | delete and tombstone tests         |
| `com.atproto.repo.applyWrites`      | implemented | batch write smoke test             |
| `com.atproto.repo.getRecord`        | implemented | record read smoke test             |
| `com.atproto.repo.listRecords`      | implemented | pagination smoke test              |
| `com.atproto.repo.describeRepo`     | implemented | repo metadata test                 |
| `com.atproto.repo.uploadBlob`       | implemented | blob smoke test                    |
| `com.atproto.repo.listMissingBlobs` | implemented | migration/blob smoke test          |
| `com.atproto.repo.importRepo`       | implemented | import rejection and restore tests |

## Sync

| Method                             |      Status | Required coverage                       |
| ---------------------------------- | ----------: | --------------------------------------- |
| `com.atproto.sync.getRepo`         | implemented | CAR export and verification test        |
| `com.atproto.sync.getBlocks`       | implemented | block CAR smoke test                    |
| `com.atproto.sync.getRecord`       | implemented | block-level record smoke test           |
| `com.atproto.sync.getLatestCommit` | implemented | commit metadata test                    |
| `com.atproto.sync.getRepoStatus`   | implemented | active/deactivated states               |
| `com.atproto.sync.listRepos`       | implemented | pagination smoke test                   |
| `com.atproto.sync.listBlobs`       | implemented | blob listing smoke test                 |
| `com.atproto.sync.getBlob`         | implemented | local and S3/R2 adapter tests           |
| `com.atproto.sync.requestCrawl`    | implemented | local test plus deployed relay check    |
| `com.atproto.sync.subscribeRepos`  | implemented | WebSocket backfill/live smoke test      |
| `com.atproto.sync.notifyOfUpdate`  |     planned | not required for current target profile |

## AppView and helpers

| Method                          |      Status | Required coverage           |
| ------------------------------- | ----------: | --------------------------- |
| `app.bsky.actor.getPreferences` | implemented | preference smoke test       |
| `app.bsky.actor.putPreferences` | implemented | preference smoke test       |
| Unknown `app.bsky.*` methods    | implemented | proxy/fallback policy tests |

## AppView proxy/fallback policy

Tempest is a PDS, not an AppView. Registered PDS-owned methods and private
compatibility helpers, including `app.bsky.actor.getPreferences` and
`app.bsky.actor.putPreferences`, are always handled locally. Unknown service
methods whose NSID starts with `app.bsky.` or `chat.bsky.` are proxy-eligible
only when `Tempest.Xrpc.Proxy` has an `upstream_base_url` configured. Proxying
forwards the original verb, query parameters or JSON body, and the `authorization`,
`accept`, and `content-type` headers, then preserves the upstream HTTP status and
response body. Without an upstream, proxy-eligible unknown methods return a
protocol-shaped `UnknownMethod` 404. Unknown `com.atproto.*` methods are never
proxied.

## Non-endpoint compatibility

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

```bash
mix test
mix test test/tempest_web/xrpc/compatibility_shapes_test.exs
hurl --test --jobs 1 --variable base_url=http://localhost:4000 test/smoke/
```

Use unique account variables when running the whole smoke directory; see
`test/smoke/README.md`.

The admin UI also renders the route-derived matrix at `/admin/compatibility` for
operator inspection. The reference table above remains the canonical maintainer
view because it records coverage expectations, not only routes.
