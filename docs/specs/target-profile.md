---
title: Target Profile - Solo Login + Archive
updated: 2026-06-03
---

# Target Profile: Solo Login + Archive

Tempest's near-term target user experience sits between:

- a single-user PDS usable by real atproto clients (login, write, read), and
- a personal data appliance (durable custody, export, verify, backup/restore).

This profile is a single node, one primary operator, and one primary identity.

## Blocking Capabilities

Tempest is considered *usable* for this profile when both tracks are true:

### Track A: Client Login Compatibility

- Identity is externally verifiable for the chosen hosted DID mode.
- Modern client auth works end-to-end (OAuth/app passwords as required).
- Records, blobs, sync reads, and firehose interoperate with known SDKs/fixtures.

### Track B: Data Custody

- Repo export is correct and repeatable.
- Repo verification can detect corruption/missing blocks.
- Backup and restore procedures are documented and exercised.

## Current Gaps

Local custody and operator features are implemented for development and local
verification. Remaining work for this profile is external proof: release
packaging, HTTPS/WebSocket deployment checks, relay/AppView crawl, real-client
login/write/read tests, and restore drills against deployed storage.

## Planned Expanded Capabilities

- multi-account hosting and community administration
- richer MFA and account recovery UX
- CDN fronting for object storage
