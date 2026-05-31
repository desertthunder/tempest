---
title: Target Profile - Solo Login + Archive
updated: 2026-05-31
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

## Planned Expanded Capabilities

- multi-account hosting and community administration
- account migration between PDS instances (service auth, activation sequencing)
- MFA and advanced account recovery UX
- S3/CDN production adapters (beyond local default)
