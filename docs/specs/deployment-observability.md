---
title: Deployment and Observability
updated: 2026-05-08
---

# Deployment and Observability

The first production target is one Phoenix release behind a TLS reverse proxy, with one writable data volume.

## Deployment Shape

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
TEMPEST_BACKUP_STORE=local
```

## Reverse Proxy

Caddy example:

```caddyfile
tempest.example.com {
  reverse_proxy 127.0.0.1:4000
}
```

WebSockets must pass through for `subscribeRepos`.

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
- Backup restore drills must verify account DB, sequencer DB, repos, blobs, signing keys, and OAuth keys together.
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
