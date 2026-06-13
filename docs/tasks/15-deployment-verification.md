---
title: Milestone 15 - Deployment and Post-deployment Verification
specs:
  - ../specs/admin-operations.md
  - ../specs/deployment-observability.md
  - ../specs/pds-compatibility.md
references:
  - ../reference/deployment-observability.md
  - ../reference/budget.md
---

Goal: make Tempest deployable, restorable, and externally verifiable as a
SQLite-first PDS on local Docker or a managed PaaS with optional S3/R2 storage.

- [x] T15-01: Add release configuration.
- [x] T15-02: Add Dockerfile.
- [x] T15-03: Add docker-compose example.
- [x] T15-04: Add Caddy reverse proxy example.
- [x] T15-05: Add production env template.
- [ ] T15-06: Add deployment docs for local-only, S3-backed, and reverse-proxy
      setups.
- [x] T15-07: Add managed PaaS deployment profile for Railway-like hosts.
- [x] T15-08: Document persistent volume requirements for SQLite, repos, keys,
      WAL files, and backup workspaces.
- [x] T15-09: Add Cloudflare R2 blob-store configuration docs.
- [x] T15-10: Add Cloudflare R2 backup-store configuration docs.
- [ ] T15-11: Add deployed HTTPS/WebSocket smoke test profile.
- [ ] T15-12: Add Hurl smoke test for deployed HTTPS target.
- [ ] T15-13: Add restore drill for managed PaaS volume plus S3/R2 backups.
- [ ] T15-14: Add public DID and handle verification procedure.
- [ ] T15-15: Add public relay/AppView crawl verification procedure for a
      deployed HTTPS node.
- [ ] T15-16: Add real-client compatibility checklist for deployed login,
      profile writes, posts, blobs, and session refresh.
- [x] T15-17: Add budget deployment guide for Railway Hobby plus Cloudflare R2
      free-tier planning.

## Integration Tests

- Release boots with a mounted data dir.
- Managed PaaS profile documents which paths must be durable.
- Production boot refuses default secrets.
- Backup docs are exercised in a local temporary directory.
- Restore drill can rebuild from a fresh volume and S3/R2 backup.
- Deployed HTTPS smoke test verifies health, XRPC, blob reads, and WebSocket
  behavior.
- Public verification proves hosted DID, handle resolution, and relay/AppView
  crawl behavior for the deployed node.

## HTTP Verification

```bash
hurl --test --jobs 1 \
  --variable base_url=https://tempest.example.com \
  --variable admin_token="$ADMIN_TOKEN" \
  test/smoke/deployment.hurl
```
