---
title: Tempest AT Protocol PDS Specification Index
updated: 2026-06-03
---

Tempest is a Phoenix application that will become a self-hostable AT Protocol
Personal Data Server.

Near-term focus: [Target Profile - Solo Login + Archive](target-profile.md).
Hosted-provider scale can come later.

Subsystem specifications live in this directory.

## Reading Order

0. [Target Profile - Solo Login + Archive](target-profile.md)
1. [Architecture](./architecture.md)
2. [XRPC HTTP Surface](./xrpc.md)
3. [SQLite Storage](./storage-sqlite.md)
4. [Accounts and Auth](accounts-auth.md)
5. [Identity and Handles](identity-handles.md)
6. [Repository Core](./repo-core.md)
7. [Record APIs](./record-apis.md)
8. [Lexicon Schema Loading and Generation](./lexicon-schemas.md)
9. [Blobs](./blobs.md)
10. [Sync and Firehose](./sync-firehose.md)
11. [Security, OAuth, and Delegated Access](./security-oauth.md)
12. [Migration and Account Lifecycle](./migration-lifecycle.md)
13. [Admin Operations](./admin-operations.md)
14. [Deployment and Observability](./deployment-observability.md)
15. [Interop and Integration Testing](./interop-testing.md)
16. [PDS Compatibility Against Reference Surface](./pds-compatibility.md)
17. [Public Stats Dashboard](./public-stats-dashboard.md)
18. [Documentation Viewer](./doc-viewer.md)
19. [Personal Account Backups](./personal-backups.md)

## Source Baseline

Research was checked on 2026-05-07 against:

- AT Protocol Repository spec: <https://atproto.com/specs/repository>
- AT Protocol Sync spec: <https://atproto.com/specs/sync>
- AT Protocol XRPC spec: <https://atproto.com/specs/xrpc>
- AT Protocol Account spec: <https://atproto.com/specs/account>
- AT Protocol DID spec: <https://atproto.com/specs/did>
- AT Protocol Handle spec: <https://atproto.com/specs/handle>
- AT Protocol Blob spec: <https://atproto.com/specs/blob>
- Blob lifecycle guide: <https://atproto.com/guides/blob-lifecycle>
- Official Bluesky PDS distribution: <https://github.com/bluesky-social/pds>
- AT Protocol Lexicons: <https://github.com/bluesky-social/atproto/tree/main/lexicons>
- AT Protocol OAuth spec: <https://atproto.com/specs/oauth>
- AT Protocol OAuth scopes guide: <https://atproto.com/guides/scopes>
- AT Protocol account migration guide: <https://atproto.com/guides/account-migration>
- Reference PDS implementation: <https://github.com/bluesky-social/atproto/tree/main/packages/pds>
- Cocoon PDS: <https://github.com/haileyok/cocoon>

## Documentation Rules

- Prefer plain technical prose.
- Keep protocol facts separate from project choices.
- Every subsystem spec must include HTTP verification.
- Every completed subsystem must have integration tests before it is considered done.
- Smoke tests must be Hurl files under `test/smoke/*.hurl` and must run with `hurl --test`.
- Use `Req` for outbound HTTP in application code.
- Run `mix precommit` before marking implementation work complete.
