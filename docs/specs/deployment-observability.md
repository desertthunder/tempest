---
title: Deployment and Observability
updated: 2026-06-02
---

# Deployment and Observability

The first production target is one Phoenix release behind HTTPS, with one
writable data volume. The HTTPS boundary may be a local reverse proxy or a
managed PaaS router.

## Local Deployment Shape

```yaml
services:
  tempest:
    image: ghcr.io/example/tempest:latest
    restart: unless-stopped
    ports:
      - "4000:4000"
    env_file:
      - tempest.env
    volumes:
      - ./data:/var/lib/tempest
```

No external database service is required for the SQLite-first version.

## Managed PaaS Shape

A Railway-like deployment still needs durable local storage for SQLite, WAL
files, repo data, signing keys, OAuth keys, and temporary backup workspaces.
Cloudflare R2 or another S3-compatible service may store blobs and backup
archives.

```text
managed service:
  Phoenix release
  persistent volume:
    account.sqlite
    sequencer.sqlite
    repos/
    keys/
object storage:
  blobs/
  backup archives/
```

Optional production adapters may add:

- S3-compatible blob storage.
- S3-compatible SQLite backup upload.
- SMTP for account verification, reset, and alert notifications.
- External metrics scraping.

## Required Environment

```text
TEMPEST_HOSTNAME=tempest.example.com
TEMPEST_PUBLIC_URL=https://tempest.example.com
TEMPEST_DATA_DIR=/var/lib/tempest
SECRET_KEY_BASE=...
TEMPEST_JWT_SECRET=...
TEMPEST_ADMIN_TOKEN_HASH=...
TEMPEST_INVITE_REQUIRED=true
TEMPEST_BLOB_STORE=local
TEMPEST_BLOB_MAX_BYTES=10000000
TEMPEST_SMTP_ENABLED=false
# SMTP profile also sets:
# TEMPEST_SMTP_HOST=smtp.example.com
# TEMPEST_SMTP_PORT=587
# TEMPEST_SMTP_USERNAME=...
# TEMPEST_SMTP_PASSWORD=...
# TEMPEST_SMTP_FROM_ADDRESS=noreply@example.com
# TEMPEST_SMTP_FROM_NAME=Tempest
# TEMPEST_SMTP_TLS=if_available
# TEMPEST_SMTP_AUTH=if_available
TEMPEST_BACKUP_STORE=local

# S3/R2-backed profiles also set:
# TEMPEST_BLOB_STORE=s3
# TEMPEST_BLOB_S3_ENDPOINT=https://<account>.r2.cloudflarestorage.com
# TEMPEST_BLOB_S3_BUCKET=tempest-blobs
# TEMPEST_BLOB_S3_REGION=auto
# TEMPEST_BLOB_S3_ACCESS_KEY_ID=...
# TEMPEST_BLOB_S3_SECRET_ACCESS_KEY=...
# TEMPEST_BLOB_S3_AUTHORIZATION=Bearer ... # optional instead of signing keys
# TEMPEST_BACKUP_STORE=s3
# TEMPEST_BACKUP_S3_ENDPOINT=https://<account>.r2.cloudflarestorage.com
# TEMPEST_BACKUP_S3_BUCKET=tempest-backups
# TEMPEST_BACKUP_S3_REGION=auto
# TEMPEST_BACKUP_S3_ACCESS_KEY_ID=...
# TEMPEST_BACKUP_S3_SECRET_ACCESS_KEY=...
# TEMPEST_BACKUP_S3_AUTHORIZATION=Bearer ... # optional instead of signing keys
```

## HTTPS and Reverse Proxy

Caddy example for local self-hosting:

```caddyfile
tempest.example.com {
  reverse_proxy 127.0.0.1:4000
}
```

WebSockets must pass through for `subscribeRepos`. Managed PaaS deployments
must verify the same behavior through the provider's HTTPS router and any
Cloudflare DNS/proxy layer.

## Telemetry

Track:

```text
xrpc.request.count
xrpc.request.duration
repo.write.count
repo.write.duration
repo.commit.count
repo.block.bytes
firehose.subscriber.count
firehose.event.count
firehose.backfill.count
blob.upload.count
blob.bytes
sqlite.query.duration
```

Use Phoenix telemetry and structured logs first. Prometheus/OpenTelemetry can follow.

## Adversarial Checks

- Production must refuse to boot with default secrets.
- Health checks must not require database writes.
- Logs must not include passwords, private keys, access tokens, refresh tokens, or admin tokens.
- Reverse proxy docs must include WebSocket behavior.
- Managed PaaS docs must identify durable paths and warn against ephemeral disk.
- Backup restore drills must verify account DB, sequencer DB, repos, blobs, signing keys, and OAuth keys together.
- S3/R2-backed deployments must prove blob reads and backup restore from object storage.
- Production docs must tell operators how to rotate JWT/OAuth/signing/admin secrets without silently invalidating account identity.

## HTTP Verification

```bash
curl -fsS https://tempest.example.com/xrpc/_health
curl -fsS https://tempest.example.com/xrpc/com.atproto.server.describeServer
curl --no-buffer "wss://tempest.example.com/xrpc/com.atproto.sync.subscribeRepos?cursor=0"
```

Expected:

- HTTPS health and `describeServer` work from outside the host.
- WebSocket upgrade succeeds through the reverse proxy.

## Sources

- <https://github.com/bluesky-social/pds>
- <https://hexdocs.pm/phoenix/deployment.html>
- <https://atproto.com/specs/sync>
