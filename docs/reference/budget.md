---
title: Budget Deployment
updated: 2026-06-12
---

This page describes the lowest-cost hosted shape for a single-user Tempest PDS:
Railway Hobby for compute and durable SQLite state, plus Cloudflare R2 Standard
storage for blob objects and backup uploads. The target is \< $10 a month.

For the step-by-step deploy flow, use [Deployment Guide](./deployment.md).

Provider prices and limits change.

The numbers below were checked on 2026-06-12 against the public Railway and
Cloudflare R2 docs.

## Target shape

```text
Railway service
  Phoenix release
  /var/lib/tempest mounted as a Railway volume
  account.sqlite
  sequencer.sqlite
  repos/
  backup workspace

Cloudflare R2 bucket: tempest-blobs
  blobs/<did>/<cid>
  temp/blobs/<did>/<cid>

Cloudflare R2 bucket or prefix: tempest-backups
  backups/tempest-backup-*.zip
```

R2 reduces pressure on the Railway volume, but it does not replace the volume.
Blob metadata, account state, sessions, signing keys, OAuth state, repo SQLite
files, and the sequencer still live under `TEMPEST_DATA_DIR`.

## Durable volume contents

The Railway volume must preserve these paths as one coherent data set:

```text
account.sqlite
account.sqlite-wal
account.sqlite-shm
sequencer.sqlite
sequencer.sqlite-wal
sequencer.sqlite-shm
repos/
blobs/
tmp/
backups/
oauth_jwks.json
```

When R2 is enabled for blobs, `blobs/` should stay small or empty after normal
operation, but the directory still belongs to the durable data layout. Per-DID
repo databases live under `repos/` and may also have SQLite WAL/SHM sidecar
files during runtime. Backups should checkpoint SQLite before copying files.

## Budget limits

Railway Hobby currently includes a small monthly usage credit and bills
additional usage. It is large enough for the compute side of a single-user PDS:
up to 8 vCPU and 8 GB RAM per replica, higher per-service aggregate limits, and
100 GB ephemeral disk. The important persistent storage limit is volume storage:
Hobby volume storage is currently up to 5 GB.

Railway ephemeral disk must not be used for `TEMPEST_DATA_DIR`. It is suitable
for build and runtime scratch only.

Cloudflare R2 Standard storage currently has a free tier of:

- 10 GB-month storage per month
- 1 million Class A operations per month
- 10 million Class B operations per month
- free egress

Use R2 Standard storage for the budget profile. The R2 free tier does not apply
to Infrequent Access storage.

For a single user, the likely first limits are blob storage size and blob read
operations, not Phoenix CPU or memory. If the account uploads images regularly,
watch total R2 GB-months and Class B reads. If the repo grows without many
blobs, watch Railway volume usage.

## Railway deployment

Create one Railway service for Tempest. Keep replicas at 1. Railway volumes do
not support multiple active replicas, and SQLite should have exactly one writer.

Attach one Railway volume and mount it at:

```text
/var/lib/tempest
```

Set the service variables:

```text
PHX_SERVER=true
SECRET_KEY_BASE=...
TEMPEST_HOSTNAME=tempest.example.com
TEMPEST_PUBLIC_URL=https://tempest.example.com
TEMPEST_DATA_DIR=/var/lib/tempest
TEMPEST_BLOB_MAX_BYTES=10000000
TEMPEST_BLOB_STORE=s3
TEMPEST_BACKUP_STORE=s3
TEMPEST_SMTP_ENABLED=false
TEMPEST_CRAWLERS=https://bsky.network,https://vsky.network
POOL_SIZE=5
```

Railway supplies `PORT`; `config/runtime.exs` reads it automatically. Do not set
`TEMPEST_HOSTNAME` to a URL. It must be the bare external host, without scheme,
path, or port.

Prefer a stable custom domain for `TEMPEST_HOSTNAME`. A temporary Railway domain
can prove that the service boots, but AT Protocol identity, OAuth metadata, and
external crawlers should be verified against the final HTTPS hostname.

After deploy, check:

```bash
curl -fsS https://tempest.example.com/xrpc/_health
curl -fsS https://tempest.example.com/xrpc/com.atproto.server.describeServer
curl --no-buffer \
  "wss://tempest.example.com/xrpc/com.atproto.sync.subscribeRepos?cursor=0"
```

## R2 blob storage

Create an R2 bucket for blobs. Public bucket access is not required for the
default profile because Tempest serves `com.atproto.sync.getBlob` through the
Phoenix app after reading the object from R2.

Create an R2 token with Object Read & Write scoped to the blob bucket. Record the
Access Key ID and Secret Access Key when Cloudflare shows them; the secret is
not shown again.

Set:

```text
TEMPEST_BLOB_S3_ENDPOINT=https://<ACCOUNT_ID>.r2.cloudflarestorage.com
TEMPEST_BLOB_S3_BUCKET=tempest-blobs
TEMPEST_BLOB_S3_REGION=auto
TEMPEST_BLOB_S3_ACCESS_KEY_ID=...
TEMPEST_BLOB_S3_SECRET_ACCESS_KEY=...
```

If the bucket uses an R2 jurisdiction, use that jurisdiction's endpoint instead
of the default account endpoint.

## R2 backup uploads

R2 can also store zipped Tempest backups. This protects against Railway volume
loss, but restore still starts from a local backup archive or extracted backup
directory.

Create either a separate backup bucket or a separate token scoped to the backup
bucket. Set:

```text
TEMPEST_BACKUP_S3_ENDPOINT=https://<ACCOUNT_ID>.r2.cloudflarestorage.com
TEMPEST_BACKUP_S3_BUCKET=tempest-backups
TEMPEST_BACKUP_S3_REGION=auto
TEMPEST_BACKUP_S3_ACCESS_KEY_ID=...
TEMPEST_BACKUP_S3_SECRET_ACCESS_KEY=...
```

Create and upload a backup from the running release environment:

```bash
mix pds.backup.create --upload-s3
```

The backup task checkpoints SQLite files, copies durable files into a backup
directory, zips the directory, and uploads the zip to the configured S3/R2
backup store.

## Restore drill

A budget deployment is not proven until restore has been tested.

1. Create an R2-uploaded backup from the live service.
2. Download and extract the backup zip into a temporary workspace.
3. Stop the Tempest service or deploy to a separate test service.
4. Attach an empty Railway volume.
5. Restore into the mounted data directory:

```bash
mix pds.backup.restore --input /path/to/extracted-backup --target /var/lib/tempest
```

6. Start the service and rerun the deployed health, describeServer, blob-read,
   DID/handle, and WebSocket checks.

Do not count R2 blob storage as a complete backup by itself. The SQLite files
and repo databases are the authoritative state tying accounts, repo commits,
and blob metadata together.

The full deployment restore runbook lives in
[`deployment observability`](./deployment-observability.md#restore-drill).

## Cost controls

Set alerts or calendar checks for:

- Railway volume usage near 4 GB
- Railway memory usage above the minimum needed for steady state
- R2 Standard storage approaching 10 GB-month
- R2 Class B operations if blobs are served heavily
- successful backup uploads and successful restore drills

Use Cloudflare R2 Standard storage for blobs and backups unless there is a clear
reason to pay for Infrequent Access retrieval and minimum-duration semantics.

## References

- Railway pricing: https://railway.com/pricing
- Railway volumes: https://docs.railway.com/volumes/reference
- Cloudflare R2 pricing: https://developers.cloudflare.com/r2/pricing/
- Cloudflare R2 tokens and S3 endpoint: https://developers.cloudflare.com/r2/api/tokens/
