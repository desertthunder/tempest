---
title: Tempest AT Protocol PDS Specification Index
updated: 2026-05-07
---

# Tempest PDS Specs

Tempest is a Phoenix application that will become a self-hostable AT Protocol Personal Data Server. The first target is a single-node server for one user or a small community. Hosted-provider scale can come later.

Subsystem specifications live in this directory. Milestone task plans live in `../tasks/`.

## Reading Order

1. [Architecture](architecture.md)
2. [XRPC HTTP Surface](xrpc.md)
3. [SQLite Storage](storage-sqlite.md)
4. [Accounts and Auth](accounts-auth.md)
5. [Identity and Handles](identity-handles.md)
6. [Repository Core](repo-core.md)
7. [Record APIs](record-apis.md)
8. [Blobs](blobs.md)
9. [Sync and Firehose](sync-firehose.md)
10. [Admin Operations](admin-operations.md)
11. [Deployment and Observability](deployment-observability.md)
12. [Interop and Integration Testing](interop-testing.md)

## Milestones

Milestone tasks live in `docs/tasks/`. Each task file is intended to be small enough to implement and review without guessing at scope. Each milestone must end with a black-box HTTP check using `curl` or `http`.

Start with [Milestone 00](../tasks/00-foundation.md), then continue in numeric order.

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

## Documentation Rules

- Prefer plain technical prose.
- Keep protocol facts separate from project choices.
- Every subsystem spec must include HTTP verification.
- Every milestone must have integration tests before it is considered done.
- Use `Req` for outbound HTTP in application code.
- Run `mix precommit` before marking implementation work complete.
