---
title: Deployment and Observability
updated: 2026-06-13
---

Tempest's first production shape is a Phoenix release behind HTTPS with one
durable data volume. SQLite databases, repo data, signing keys, OAuth keys, blob
state, and backup workspaces must live on durable storage.

For a step-by-step Railway deployment path, use
[Deployment Guide](./deployment.md).

## Deployment profiles

Tempest supports three deployment profiles for the current single-node target:

- local-only with all state under `TEMPEST_DATA_DIR`;
- local release or container behind a reverse proxy, usually Caddy;
- managed PaaS, currently documented as Railway plus optional Cloudflare R2.

All profiles use one running Tempest instance. Do not run multiple writers
against the same data directory. SQLite, repo storage, sequencer state, OAuth
keys, signing keys, and backup workspaces must move together.

## Local-only profile

Use this profile for local proving, private LAN testing, or a single host where
Phoenix terminates HTTP directly.

```yaml
services:
  tempest:
    image: ghcr.io/example/tempest:latest
    restart: unless-stopped
    ports:
      - "4000:4000"
    env_file:
      - .env
    volumes:
      - ./data:/var/lib/tempest
```

No external database service is required for the SQLite-first profile.

For a release or container, the mounted data path must be durable:

```text
TEMPEST_DATA_DIR=/var/lib/tempest
```

Local-only verification:

```bash
curl -fsS http://localhost:4000/xrpc/_health
curl -fsS http://localhost:4000/xrpc/com.atproto.server.describeServer
```

This profile does not prove public DID, handle, relay, AppView, OAuth, or
WebSocket behavior unless the host is reachable from the public internet.

## S3/R2-backed profile

Use this profile when blob bytes and backup archives should live outside the
local volume. R2 or another S3-compatible store does not replace the durable
Tempest data directory. Account state, sessions, repo SQLite files, the
sequencer, metadata, and key material still live under `TEMPEST_DATA_DIR`.

Set blob storage:

```text
TEMPEST_BLOB_STORE=s3
TEMPEST_BLOB_S3_ENDPOINT=https://<ACCOUNT_ID>.r2.cloudflarestorage.com
TEMPEST_BLOB_S3_BUCKET=tempest-blobs
TEMPEST_BLOB_S3_REGION=auto
TEMPEST_BLOB_S3_ACCESS_KEY_ID=...
TEMPEST_BLOB_S3_SECRET_ACCESS_KEY=...
```

Set backup uploads:

```text
TEMPEST_BACKUP_STORE=s3
TEMPEST_BACKUP_S3_ENDPOINT=https://<ACCOUNT_ID>.r2.cloudflarestorage.com
TEMPEST_BACKUP_S3_BUCKET=tempest-backups
TEMPEST_BACKUP_S3_REGION=auto
TEMPEST_BACKUP_S3_ACCESS_KEY_ID=...
TEMPEST_BACKUP_S3_SECRET_ACCESS_KEY=...
```

Use separate buckets or separate scoped credentials when possible. The blob
bucket needs object read/write for normal operation. The backup bucket needs
write for backup creation and read for restore drills.

## Reverse-proxy profile

A reverse proxy terminates HTTPS and forwards HTTP/WebSocket traffic to Phoenix.
The proxy must preserve host headers and pass WebSocket upgrades for:

```text
/xrpc/com.atproto.sync.subscribeRepos
```

A local Caddy deployment can use:

```caddyfile
tempest.example.com {
  reverse_proxy 127.0.0.1:4000
}
```

`TEMPEST_HOSTNAME` must be the bare external hostname. `TEMPEST_PUBLIC_URL` must
match the external HTTPS origin because DID documents and OAuth metadata use it
as the service boundary.

```text
TEMPEST_HOSTNAME=tempest.example.com
TEMPEST_PUBLIC_URL=https://tempest.example.com
```

Do not use a temporary host for account migration. It can prove boot, but DID
documents, handles, OAuth clients, relays, and AppViews should be verified
against the final hostname.

## Railway profile

For the single-user Railway plus Cloudflare R2 budget profile, see
[`budget`](./budget.md).

Railway-specific rules:

- use one Railway service;
- keep replicas at 1;
- attach one volume at `/var/lib/tempest`;
- set `TEMPEST_DATA_DIR=/var/lib/tempest`;
- let Railway provide `PORT`;
- use the final custom domain for `TEMPEST_HOSTNAME`.

Railway volumes are persistent, but Railway documents several caveats relevant
to Tempest: each service can only have one volume, replicas cannot be used with
volumes, and deployments with an attached volume may have a short downtime window
because multiple active deployments cannot mount the same service volume safely.
The volume must be configured in Railway, not with a Dockerfile `VOLUME`
instruction.

## Required environment

```text
TEMPEST_HOSTNAME=tempest.example.com
TEMPEST_PUBLIC_URL=https://tempest.example.com
TEMPEST_DATA_DIR=/var/lib/tempest
SECRET_KEY_BASE=...
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

## Deployed smoke profile

Run these checks against the final external hostname. Do not count localhost,
private DNS, or a temporary Railway domain as deployment verification.

Set variables:

```bash
export BASE_URL=https://tempest.example.com
export HOSTNAME=tempest.example.com
export ADMIN_TOKEN=...
```

Health and metadata:

```bash
curl -fsS "$BASE_URL/xrpc/_health"
curl -fsS "$BASE_URL/xrpc/com.atproto.server.describeServer"
curl -fsS "$BASE_URL/.well-known/oauth-protected-resource"
curl -fsS "$BASE_URL/.well-known/oauth-authorization-server"
```

Admin status:

```bash
curl -fsS \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$BASE_URL/xrpc/_admin/status"
```

Non-destructive Hurl smoke:

```bash
hurl --test --jobs 1 \
  --variable base_url="$BASE_URL" \
  --variable admin_token="$ADMIN_TOKEN" \
  test/smoke/deployment.hurl
```

WebSocket firehose:

```bash
websocat "wss://$HOSTNAME/xrpc/com.atproto.sync.subscribeRepos?cursor=0"
```

If `websocat` is not available, use any WebSocket client that reports connection
failure and frame output clearly. An idle connection is acceptable immediately
after deploy; the important first check is that the HTTPS upgrade succeeds.

## Restore drill

A managed deployment is not proven until a restore has booted from separate
storage. For Railway plus R2, use a separate test service or stop the live
service before attaching an empty volume.

1. Create a backup from the running release.

   ```bash
   bin/tempest eval 'case Tempest.Admin.Backup.create(upload?: true) do {:ok, result} -> IO.inspect(result); {:error, reason} -> raise inspect(reason) end'
   ```

   If running from a Mix environment instead of a release:

   ```bash
   mix pds.backup.create --upload-s3
   ```

2. Confirm the backup archive exists in the configured backup bucket.
3. Download and extract the backup archive into a temporary workspace.
4. Attach an empty Railway volume to a test service, mounted at
   `/var/lib/tempest`.
5. Restore into the empty mounted directory:

   ```bash
   bin/tempest eval 'case Tempest.Admin.Backup.restore("/path/to/extracted-backup", target: "/var/lib/tempest") do {:ok, result} -> IO.inspect(result); {:error, reason} -> raise inspect(reason) end'
   ```

   Or, from a Mix environment:

   ```bash
   mix pds.backup.restore \
     --input /path/to/extracted-backup \
     --target /var/lib/tempest
   ```

6. Start the restored service with the same runtime variables, except use a test
   hostname if the original identity must not move.
7. Re-run health, describeServer, admin status, blob read, repo read, DID/handle,
   and WebSocket checks.

Do not treat R2 blob storage as a complete backup. The SQLite files, repo
databases, sequencer, keys, and metadata are the state that explains which blobs
belong to which account.

## Public identity verification

For each hosted account used in deployment testing, record:

```text
HANDLE=alice.example.com
DID=did:plc:...
BASE_URL=https://tempest.example.com
```

Verify handle resolution through Tempest:

```bash
curl -fsS \
  "$BASE_URL/xrpc/com.atproto.identity.resolveHandle?handle=$HANDLE"
```

Verify handle well-known resolution when the handle host is controlled by this
deployment:

```bash
curl -fsS "https://$HANDLE/.well-known/atproto-did"
```

Verify the DID document with the appropriate resolver. For `did:plc`, fetch the
PLC document:

```bash
curl -fsS "https://plc.directory/$DID"
```

For `did:web`, fetch the DID document from its well-known URL.

The DID document must include:

```text
alsoKnownAs: at://<handle>
service id: #atproto_pds
serviceEndpoint: <TEMPEST_PUBLIC_URL>
```

Only activate or migrate an account after the public DID document points at the
final `TEMPEST_PUBLIC_URL`. Existing services may cache identity; after a change,
repeat the checks from a network outside the deployment provider.

## Relay and AppView crawl verification

Configure public crawlers:

```text
TEMPEST_CRAWLERS=https://bsky.network,https://vsky.network
```

Run the deployed crawler smoke test:

```bash
hurl --test --jobs 1 \
  --variable base_url="$BASE_URL" \
  --variable crawler_hostname="$HOSTNAME" \
  test/smoke/deployed/crawlers.hurl
```

Then create a small repo-visible event from a real or smoke account, such as a
profile update or post, and verify:

- `com.atproto.sync.getLatestCommit` returns the new rev;
- `com.atproto.sync.getRepo` returns a CAR for the account DID;
- `com.atproto.sync.subscribeRepos` emits a commit frame for new writes;
- a relay or AppView that can crawl the hostname no longer reports the PDS as
  unreachable.

If a relay appears stale, first verify that DNS, TLS, `TEMPEST_PUBLIC_URL`, and
WebSocket upgrades are correct. Then run `com.atproto.sync.requestCrawl` again
against the deployed hostname.

## Real-client checklist

Use at least one real client against the final hostname before migrating the
admin account. Record the client name and date.

- Add the custom service URL in the client.
- Log in with the test account.
- Refresh the session or close/reopen the client and confirm the session still
  works.
- Read the profile.
- Update the profile display name or description.
- Create a post.
- Upload an image blob and create a record that references it.
- Read the post and blob back through the client.
- Revoke or rotate an app password if the client used one.
- Confirm admin routes still reject normal account tokens.
- Confirm the same writes appear through repo reads and the firehose.

Do not use the admin account as the first client test. Use a disposable account
or an inactive migration test account until the service has passed restore and
public identity checks.

## Verification summary

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

## Sources checked

- Railway Phoenix guide: <https://docs.railway.com/guides/phoenix>
- Railway volumes reference: <https://docs.railway.com/volumes/reference>
- AT Protocol account migration guide:
  <https://atproto.com/guides/account-migration>
- AT Protocol handle spec: <https://atproto.com/specs/handle>
