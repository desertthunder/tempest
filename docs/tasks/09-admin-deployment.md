---
title: Milestone 09 - Admin and Deployment
specs:
  - ../specs/admin-operations.md
  - ../specs/deployment-observability.md
---

Goal: make Tempest deployable and maintainable as a single-node self-hosted PDS.

## Tasks

- [ ] T09-01: Add release configuration.
- [ ] T09-02: Add Dockerfile.
- [ ] T09-03: Add docker-compose example.
- [ ] T09-04: Add Caddy reverse proxy example.
- [ ] T09-05: Add production env template.
- [ ] T09-06: Add admin token hashing and verification.
- [ ] T09-07: Add admin status endpoint.
- [ ] T09-08: Add `mix pds.repo.verify`.
- [ ] T09-09: Add `mix pds.repo.export`.
- [ ] T09-10: Add `mix pds.repo.import`.
- [ ] T09-11: Add `mix pds.sequencer.status`.
- [ ] T09-12: Add `mix pds.blob.gc`.
- [ ] T09-13: Add backup create/restore docs.
- [ ] T09-14: Add Hurl smoke test for deployed HTTPS target.
- [ ] T09-15: Add telemetry events for XRPC, repo writes, blobs, and firehose.

## Integration Tests

- Release boots with mounted data dir.
- Admin status requires admin token.
- Repo verify catches corrupted or missing blocks.
- Backup docs are exercised in a local temporary directory.

## HTTP Verification

```bash
hurl --test --jobs 1 \
  --variable base_url=https://tempest.example.com \
  --variable admin_token="$ADMIN_TOKEN" \
  test/smoke/deployment.hurl
```
