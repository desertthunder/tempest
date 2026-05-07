---
title: Milestone 00 - Foundation
specs:
  - ../specs/architecture.md
  - ../specs/storage-sqlite.md
---

Goal: make the project ready for PDS implementation without changing protocol behavior yet.

## Tasks

- [ ] T00-01: Add `TEMPEST_DATA_DIR` config with dev/test defaults under `priv/tempest_dev` and test temp directories.
- [ ] T00-02: Add a `Tempest.Config` module that validates hostname, public URL, data dir, and blob limits.
- [ ] T00-03: Add a public `/xrpc/_health` route that returns JSON.
- [ ] T00-04: Include app version and boot status in health output.
- [ ] T00-05: Add test coverage for health success.
- [ ] T00-06: Add test coverage for invalid config refusing to boot.
- [ ] T00-07: Document local server startup and Hurl smoke-test commands.
- [ ] T00-08: Add a `test/smoke` directory placeholder with README.

## Integration Tests

- Health endpoint returns JSON.
- Health endpoint does not require auth.
- Production config rejects default secrets.

## HTTP Verification

```bash
hurl --test --variable base_url=http://localhost:4000 test/smoke/health.hurl
```

Expected JSON fields:

```text
version
status
```

## Done

Run:

```bash
mix precommit
```
