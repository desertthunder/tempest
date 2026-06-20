---
title: Milestone 14 - Local PDS Compatibility Testing
specs:
  - ../specs/pds-compatibility.md
  - ../specs/interop-testing.md
  - ../specs/security-oauth.md
  - ../specs/migration-lifecycle.md
---

Completed [June 12, 2026](../../CHANGELOG.md#2026-06-12).

## Verification

```bash
test/smoke/local-pds-compat.sh http://localhost:4000
```

The local profile proves endpoint shape, auth boundaries, content types, black-box
account/repo/blob/CAR/firehose flows, migration behavior, AppView fallback policy,
and restore-drill compatibility before deployment.

Reference documentation:

- [PDS Compatibility Matrix](../reference/pds-compatibility.md)
- [Interop and Integration Testing](../reference/interop-testing.md)
- [Security, OAuth, and Delegated Access](../reference/security-oauth.md)
- [Migration and Account Lifecycle](../reference/migration-lifecycle.md)
