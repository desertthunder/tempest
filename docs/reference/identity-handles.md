---
title: Identity and Handles
updated: 2026-06-13
---

Tempest follows the AT Protocol identity model:

a DID is the durable identity key for a repository, and a handle is the user-facing name,
allowing handle ownership to change without changing repository authority.

Clients resolve a handle to a DID, then trust that DID to identify the repository they are
allowed to read or write. It's important to note that a DID does not imply a stable handle
for the user-visible surface.

## Reference Material

- AT Protocol identity spec: <https://atproto.com/specs/identity>
- AT Protocol handle spec: <https://atproto.com/specs/handle>
- AT Protocol DID spec: <https://atproto.com/specs/did>
- AT Protocol Lexicon: <https://atproto.com/specs/lexicon>
- DID Core (W3C): <https://www.w3.org/TR/did-core/>
- DID web method registry notes: <https://w3c.github.io/did-spec-registries/#did-web>
- PLC method design notes: <https://w3c.github.io/did-spec-registries/#did-plc>
- did:web and did:plc comparison: <https://github.com/threeidchain/plc/blob/master/README.md>

## Identity and handle contract

- Handle values are for presentation and discovery.
- DIDs are stable and remain the truth for repository authority.
- A well-formed service binding in the DID document connects the DID to the PDS
  endpoints used by clients.
- `alsoKnownAs` links the DID to the handle so clients and tooling can cross-check
  ownership and move between identities predictably.

## Violations

A deployment that lets handle-to-DID resolution drift becomes hard to reason about:

- Repo writes can be rejected or misrouted.
- Migration and backup tooling can target the wrong signer context.
- Crawlers and relays can lose track of ownership during sync.
- Trust checks in clients that compare handle and DID can fail.

## Invariants

Operators validate these invariants in smoke and deployment checks:

- Handle resolves to the same DID that the account claims.
- DID document service routes remain stable for hosted endpoints.
- `alsoKnownAs` and handle mapping agree after updates.
- New identities and moved identities retain ownership checks consistently.

## Context

- [Identity troubleshooting](./identity-troubleshooting.md)
- [Migration and Account Lifecycle](./migration-lifecycle.md)
- [PDS Compatibility Matrix](./pds-compatibility.md)
