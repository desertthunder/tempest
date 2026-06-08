---
title: Deployment and Observability
updated: 2026-06-03
---

Tempest's first production shape is a Phoenix release behind HTTPS with one
durable data volume. SQLite databases, repo data, signing keys, OAuth keys, blob
state, and backup workspaces must live on durable storage.

## Local deployment shape

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

No external database service is required for the SQLite-first profile.

## Required environment

```text
TEMPEST_HOSTNAME=tempest.example.com
TEMPEST_PUBLIC_URL=https://tempest.example.com
TEMPEST_DATA_DIR=/var/lib/tempest
SECRET_KEY_BASE=...
TEMPEST_JWT_SECRET=...
TEMPEST_ADMIN_TOKEN_HASH=...
TEMPEST_BLOB_STORE=local
TEMPEST_BLOB_MAX_BYTES=10000000
TEMPEST_SMTP_ENABLED=false
TEMPEST_BACKUP_STORE=local
TEMPEST_CRAWLERS=https://bsky.network,https://vsky.network
```

Optional adapters add SMTP, S3/R2 blob storage, and S3/R2 backup uploads. Those
profiles also need endpoint, bucket, region, and credential variables for the
chosen object store.

## Durable paths

A deployment must preserve these paths together:

```text
account.sqlite
sequencer.sqlite
repos/
blobs/
keys or key material managed by config
oauth_jwks.json
backups/
```

Losing only one of these can make accounts unverifiable. For example, repo data
without signing keys cannot safely emit new commits, and blobs without repo state
cannot prove which blobs are public.

## HTTPS and WebSockets

A local Caddy deployment can terminate HTTPS and proxy Phoenix:

```caddyfile
tempest.example.com {
  reverse_proxy 127.0.0.1:4000
}
```

The reverse proxy must pass WebSocket upgrades for:

```text
/xrpc/com.atproto.sync.subscribeRepos
```

`TEMPEST_PUBLIC_URL` must match the externally reachable URL because DID
documents and OAuth metadata use it as the service boundary.

## Observability

Tempest emits telemetry and structured logs around the public protocol surface.
Important event families include:

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

The admin status endpoint and dashboard expose operator-readable health:

```text
GET /xrpc/_health
GET /xrpc/_admin/status
GET /admin
GET /admin/storage
```

`/_health` is public and minimal. Admin status requires the admin token.

## Verification

Local:

```bash
curl -fsS http://localhost:4000/xrpc/_health
curl -fsS http://localhost:4000/xrpc/com.atproto.server.describeServer
```

Deployed:

```bash
curl -fsS https://tempest.example.com/xrpc/_health
curl -fsS https://tempest.example.com/xrpc/com.atproto.server.describeServer
curl --no-buffer \
  "wss://tempest.example.com/xrpc/com.atproto.sync.subscribeRepos?cursor=0"
```

A deployment is not verified until HTTPS, DID/handle resolution, WebSockets,
blob reads, and restore drills all work from outside the host.
