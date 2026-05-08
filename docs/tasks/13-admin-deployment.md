---
title: Milestone 13 - Admin and Deployment
specs:
  - ../specs/admin-operations.md
  - ../specs/deployment-observability.md
---

Goal: make Tempest deployable and maintainable as a single-node self-hosted PDS.

## Tasks

- [ ] T13-01: Add release configuration.
- [ ] T13-02: Add Dockerfile.
- [ ] T13-03: Add docker-compose example.
- [ ] T13-04: Add Caddy reverse proxy example.
- [ ] T13-05: Add production env template.
- [ ] T13-06: Add admin token hashing and verification.
- [ ] T13-07: Add admin status endpoint.
- [ ] T13-08: Add `mix pds.repo.verify`.
- [ ] T13-09: Add `mix pds.repo.export`.
- [ ] T13-10: Add `mix pds.repo.import`.
- [ ] T13-11: Add `mix pds.sequencer.status`.
- [ ] T13-12: Add `mix pds.blob.gc`.
- [ ] T13-13: Add backup create/restore docs.
- [ ] T13-14: Add Hurl smoke test for deployed HTTPS target.
- [ ] T13-15: Add telemetry events for XRPC, repo writes, blobs, and firehose.
- [ ] T13-16: Add SMTP env and verification for account email flows.
- [ ] T13-17: Add S3 backup configuration docs.
- [ ] T13-18: Add restore drill that validates accounts, sequencer, repos, blobs, and keys together.

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
