---
title: Endpoint Reference
updated: 2026-06-14
---

# Endpoint Reference

This reference lists the public service routes and registered XRPC methods exposed by Tempest. It is intentionally documentation-only; the homepage should summarize system status, not carry a full endpoint inventory.

## Service Routes

| Method | Path                                      | Access      |
| ------ | ----------------------------------------- | ----------- |
| GET    | `/.well-known/atproto-did`                | public      |
| GET    | `/.well-known/did.json`                   | public      |
| GET    | `/.well-known/oauth-protected-resource`   | metadata    |
| GET    | `/.well-known/oauth-authorization-server` | metadata    |
| GET    | `/oauth/jwks`                             | metadata    |
| GET    | `/xrpc/_health`                           | operational |
| GET    | `/xrpc/_stats`                            | public      |
| GET    | `/xrpc/_admin/status`                     | operational |

## XRPC Methods

| HTTP   | Auth   | NSID                                                |
| ------ | ------ | --------------------------------------------------- |
| GET    | bearer | `app.bsky.actor.getPreferences`                     |
| POST   | bearer | `app.bsky.actor.putPreferences`                     |
| GET    | bearer | `com.atproto.identity.getRecommendedDidCredentials` |
| POST   | bearer | `com.atproto.identity.requestPlcOperationSignature` |
| GET    | public | `com.atproto.identity.resolveHandle`                |
| POST   | bearer | `com.atproto.identity.signPlcOperation`             |
| POST   | bearer | `com.atproto.identity.submitPlcOperation`           |
| POST   | bearer | `com.atproto.identity.updateHandle`                 |
| POST   | bearer | `com.atproto.repo.applyWrites`                      |
| POST   | bearer | `com.atproto.repo.createRecord`                     |
| POST   | bearer | `com.atproto.repo.deleteRecord`                     |
| GET    | public | `com.atproto.repo.describeRepo`                     |
| GET    | public | `com.atproto.repo.getRecord`                        |
| POST   | bearer | `com.atproto.repo.importRepo`                       |
| GET    | bearer | `com.atproto.repo.listMissingBlobs`                 |
| GET    | public | `com.atproto.repo.listRecords`                      |
| POST   | bearer | `com.atproto.repo.putRecord`                        |
| POST   | bearer | `com.atproto.repo.uploadBlob`                       |
| POST   | bearer | `com.atproto.server.activateAccount`                |
| GET    | bearer | `com.atproto.server.checkAccountStatus`             |
| POST   | public | `com.atproto.server.confirmEmail`                   |
| POST   | public | `com.atproto.server.createAccount`                  |
| POST   | bearer | `com.atproto.server.createAppPassword`              |
| POST   | public | `com.atproto.server.createSession`                  |
| POST   | bearer | `com.atproto.server.deactivateAccount`              |
| POST   | bearer | `com.atproto.server.deleteAccount`                  |
| POST   | bearer | `com.atproto.server.deleteSession`                  |
| GET    | public | `com.atproto.server.describeServer`                 |
| GET    | bearer | `com.atproto.server.getServiceAuth`                 |
| GET    | bearer | `com.atproto.server.getSession`                     |
| GET    | bearer | `com.atproto.server.listAppPasswords`               |
| POST   | bearer | `com.atproto.server.refreshSession`                 |
| POST   | bearer | `com.atproto.server.requestAccountDelete`           |
| POST   | bearer | `com.atproto.server.requestEmailConfirmation`       |
| POST   | bearer | `com.atproto.server.requestEmailUpdate`             |
| POST   | public | `com.atproto.server.requestPasswordReset`           |
| POST   | bearer | `com.atproto.server.reserveSigningKey`              |
| POST   | public | `com.atproto.server.resetPassword`                  |
| POST   | bearer | `com.atproto.server.revokeAppPassword`              |
| POST   | public | `com.atproto.server.updateEmail`                    |
| GET    | public | `com.atproto.sync.getBlob`                          |
| GET    | public | `com.atproto.sync.getBlocks`                        |
| GET    | public | `com.atproto.sync.getLatestCommit`                  |
| GET    | public | `com.atproto.sync.getRecord`                        |
| GET    | public | `com.atproto.sync.getRepo`                          |
| GET    | public | `com.atproto.sync.getRepoStatus`                    |
| GET    | public | `com.atproto.sync.listBlobs`                        |
| GET    | public | `com.atproto.sync.listRepos`                        |
| POST   | public | `com.atproto.sync.requestCrawl`                     |
| STREAM | public | `com.atproto.sync.subscribeRepos`                   |
