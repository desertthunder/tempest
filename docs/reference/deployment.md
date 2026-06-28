---
title: Deployment Guide
updated: 2026-06-13
---

This guide deploys Tempest as a single-user PDS on Railway with one persistent
volume and optional Cloudflare R2 storage for blobs and backup archives.

Use this guide with:

- [Initial Release Readiness](./release.md)
- [Deployment and Observability](./deployment-observability.md)
- [Budget Deployment](./budget.md)

## Before You Start

Choose the final public hostname first.

```text
TEMPEST_HOSTNAME=tempest.example.com
TEMPEST_PUBLIC_URL=https://tempest.example.com
```

`TEMPEST_HOSTNAME` is the bare host only. Do not include scheme, path, or port.
Do not migrate a real account to a temporary Railway hostname. DID documents,
handles, OAuth metadata, relays, and AppViews should be verified against the
final HTTPS hostname.

Required local tools:

```bash
mix phx.gen.secret
hurl --version
docker --version
```

Generate secrets from a trusted local machine:

```bash
mix phx.gen.secret
uv run --project scripts tempest argon
```

Store the raw `ADMIN_TOKEN` in a password manager. Railway gets only
`TEMPEST_ADMIN_TOKEN_HASH`.

## Build Check

Before deploying, prove the release image builds:

```bash
docker build -f conf/Dockerfile -t tempest:release-check .
docker rmi tempest:release-check
```

Run the normal project gate:

```bash
mix precommit
```

## Create R2 Buckets

R2 is recommended for the first hosted deployment. It keeps blob bytes and backup
archives off the Railway volume, but it does not replace the volume.

Create two buckets or two separately scoped prefixes:

```text
tempest-blobs
tempest-backups
```

Create scoped R2 tokens:

- blob bucket: Object Read and Write
- backup bucket: Object Read and Write

Record the account endpoint:

```text
https://<ACCOUNT_ID>.r2.cloudflarestorage.com
```

If the bucket uses an R2 jurisdiction, use the jurisdiction endpoint instead.

## Create Railway Service

Create one Railway service for Tempest.

Required service shape:

```text
replicas=1
volume mount=/var/lib/tempest
```

Do not run multiple replicas. Railway volumes do not support active replicas,
and Tempest's SQLite profile expects one writer.
Configure the volume in Railway. The Dockerfile intentionally does not use a
Docker `VOLUME` instruction because Railway rejects it; the mount must come from
Railway's volume settings.

The container entrypoint starts as root only long enough to create and chown the
mounted `TEMPEST_DATA_DIR` tree. Bootstrap, migrations, and the Phoenix release
then run as the unprivileged `tempest` user. This is required because Railway
volume mounts may not arrive owned by the image user.

Set the custom domain in Railway before migrating an account. Wait for DNS and
TLS to become healthy.

## Set Railway Variables

Minimum variables:

```text
PHX_SERVER=true
POOL_SIZE=5
SECRET_KEY_BASE=<generated secret>
TEMPEST_HOSTNAME=tempest.example.com
TEMPEST_PUBLIC_URL=https://tempest.example.com
TEMPEST_DATA_DIR=/var/lib/tempest
TEMPEST_HOSTED_DID_METHOD=plc
TEMPEST_ADMIN_TOKEN_HASH=<argon2 hash>
TEMPEST_BLOB_MAX_BYTES=10000000
TEMPEST_CRAWLERS=https://bsky.network,https://vsky.network
```

Railway supplies `PORT`; leave it unset unless you have a specific reason to
override Railway's value.

R2 blob storage:

```text
TEMPEST_BLOB_STORE=s3
TEMPEST_BLOB_S3_ENDPOINT=https://<ACCOUNT_ID>.r2.cloudflarestorage.com
TEMPEST_BLOB_S3_BUCKET=tempest-blobs
TEMPEST_BLOB_S3_REGION=auto
TEMPEST_BLOB_S3_ACCESS_KEY_ID=...
TEMPEST_BLOB_S3_SECRET_ACCESS_KEY=...
```

R2 backup uploads:

```text
TEMPEST_BACKUP_STORE=s3
TEMPEST_BACKUP_S3_ENDPOINT=https://<ACCOUNT_ID>.r2.cloudflarestorage.com
TEMPEST_BACKUP_S3_BUCKET=tempest-backups
TEMPEST_BACKUP_S3_REGION=auto
TEMPEST_BACKUP_S3_ACCESS_KEY_ID=...
TEMPEST_BACKUP_S3_SECRET_ACCESS_KEY=...
```

Optional email delivery:

```text
TEMPEST_EMAIL_PROVIDER=local
```

Leave email on `local` for the first deployment unless password reset and email
confirmation delivery have been configured and tested.

### Provider selection

`TEMPEST_EMAIL_PROVIDER` selects the Swoosh adapter. `local` (default) stores
email in memory for dev/test. Production uses `resend` (recommended) or `smtp`.
Production with no provider set keeps `local` rather than failing; an operator
who wants real delivery must opt in.

Resend (recommended for production):

```text
TEMPEST_EMAIL_PROVIDER=resend
TEMPEST_RESEND_API_KEY=...
TEMPEST_EMAIL_FROM_NAME=Tempest
TEMPEST_EMAIL_FROM_ADDRESS=no-reply@<verified-domain>
```

`config/prod.exs` already configures `Swoosh.ApiClient.Req`, which satisfies the
Resend adapter's API-client requirement.

SMTP fallback (for environments that cannot use the Resend API; the Resend SMTP
relay accepts the API key as the password):

```text
TEMPEST_EMAIL_PROVIDER=smtp
TEMPEST_SMTP_HOST=smtp.resend.com
TEMPEST_SMTP_PORT=587
TEMPEST_SMTP_USERNAME=resend
TEMPEST_SMTP_PASSWORD=<resend_api_key>
TEMPEST_SMTP_SSL=false
TEMPEST_SMTP_TLS=always
TEMPEST_SMTP_AUTH=always
TEMPEST_EMAIL_FROM_NAME=Tempest
TEMPEST_EMAIL_FROM_ADDRESS=no-reply@example.com
```

The API adapter is preferred over SMTP for Resend because it supports provider
tags and idempotency keys.

### Backwards compatibility

`TEMPEST_SMTP_ENABLED=true` still selects `smtp` when
`TEMPEST_EMAIL_PROVIDER` is unset, so existing deployments keep working. The
legacy `TEMPEST_SMTP_FROM_NAME` and `TEMPEST_SMTP_FROM_ADDRESS` variables are
honored as aliases for the shared `TEMPEST_EMAIL_FROM_*` names; prefer the
shared names for new deployments.

### Fail-closed behavior

In production, selecting `resend` without `TEMPEST_RESEND_API_KEY` or
`TEMPEST_EMAIL_FROM_ADDRESS` raises at boot with a clear message. The same
applies to `smtp` without `TEMPEST_SMTP_HOST` or a from address. Non-production
environments fall back to `local` when credentials are missing so tests and dev
never block on email config.

### DNS: SPF, DKIM, and DMARC

The Resend sending domain must be verified before production testing. Configure
the DNS records Resend provides:

- **SPF** (`TXT` on the root domain): authorize Resend's mail servers. Resend
  provides the include value during domain verification.
- **DKIM** (`CNAME` or `TXT` records): Resend provides the selector and public
  key material. DKIM signs outgoing messages so recipients can verify they were
  not modified in transit.
- **DMARC** (`TXT` record at `_dmarc.<domain>`): publish a policy
  (`p=quarantine` or `p=reject`) with an aggregate report address. Start with
  `p=none` to monitor, then tighten once SPF/DKIM alignment is confirmed.

Verify DNS propagation with `dig` or `nslookup` before sending production email.

### Email verification

Local verification:

```bash
mix test test/tempest/security_test.exs test/tempest_web/xrpc/email_flows_test.exs
```

Production-style local verification with Resend config (no network calls):

```bash
TEMPEST_EMAIL_PROVIDER=resend \
TEMPEST_RESEND_API_KEY="$TEMPEST_RESEND_API_KEY" \
TEMPEST_EMAIL_FROM_ADDRESS="$TEMPEST_EMAIL_FROM_ADDRESS" \
mix test test/tempest/security/email_delivery_config_test.exs
```

Deployed smoke verification:

```bash
hurl --test --jobs 1 \
  --variable base_url=https://tempest.example.com \
  --variable account_email=reset-target@example.com \
  test/smoke/email-security.hurl
```

See [Email Delivery](./email-delivery.md) for the security model behind these
flows and why token state lives in the database rather than R2.

## First Boot

Deploy the service. The Docker entrypoint prepares the mounted storage layout,
bootstraps SQLite, runs migrations, and starts the Phoenix release as the
`tempest` user.

Check Railway logs for startup errors. Then verify externally:

```bash
export BASE_URL=https://tempest.example.com
export HOSTNAME=tempest.example.com
export ADMIN_TOKEN=<raw admin token>

curl -fsS "$BASE_URL/xrpc/_health"
curl -fsS "$BASE_URL/xrpc/com.atproto.server.describeServer"
curl -fsS \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$BASE_URL/xrpc/_admin/status"
```

Run the deployed HTTPS smoke test:

```bash
hurl --test --jobs 1 \
  --variable base_url="$BASE_URL" \
  --variable admin_token="$ADMIN_TOKEN" \
  test/smoke/deployment.hurl
```

## WebSocket Check

Verify the firehose WebSocket upgrades over HTTPS:

```bash
websocat "wss://$HOSTNAME/xrpc/com.atproto.sync.subscribeRepos?cursor=0"
```

An idle connection is acceptable before any account writes. The first check is
that the connection upgrades successfully and does not fail at the proxy or TLS
layer.

## Relay Crawl Check

Run the crawler smoke test against the public hostname:

```bash
hurl --test --jobs 1 \
  --variable base_url="$BASE_URL" \
  --variable crawler_hostname="$HOSTNAME" \
  test/smoke/deployed/crawlers.hurl
```

This only proves that Tempest accepts the crawl request shape. Full federation
proof also requires a repo-visible write and checking that external relays or
AppViews can fetch the repo.

## Backup and Restore Drill

Create an uploaded backup from the running release:

```bash
bin/tempest eval 'case Tempest.Admin.Backup.create(upload?: true) do {:ok, result} -> IO.inspect(result); {:error, reason} -> raise inspect(reason) end'
```

Confirm the archive exists in R2. Download and extract it locally or in a restore
workspace.

Restore into a separate test service or stopped service with an empty volume:

```bash
bin/tempest eval 'case Tempest.Admin.Backup.restore("/path/to/extracted-backup", target: "/var/lib/tempest") do {:ok, result} -> IO.inspect(result); {:error, reason} -> raise inspect(reason) end'
```

Start the restored service and rerun:

```bash
hurl --test --jobs 1 \
  --variable base_url="$BASE_URL" \
  --variable admin_token="$ADMIN_TOKEN" \
  test/smoke/deployment.hurl
```

R2 blob storage is not a complete backup by itself. The SQLite files, repo
databases, sequencer, OAuth keys, signing keys, and metadata under
`TEMPEST_DATA_DIR` are the authoritative state.

## Identity Check

Before migrating any real account, verify identity from outside Railway.

For a test account:

```bash
export HANDLE=alice.example.com
export DID=did:plc:...

curl -fsS "$BASE_URL/xrpc/com.atproto.identity.resolveHandle?handle=$HANDLE"
curl -fsS "https://plc.directory/$DID"
```

The public DID document must include:

```text
alsoKnownAs: at://<handle>
service id: #atproto_pds
serviceEndpoint: <TEMPEST_PUBLIC_URL>
```

For `did:web`, fetch the DID document from the handle's well-known URL instead
of PLC.

## Real Client Check

Use a disposable account before the admin account.

- Add the custom service URL in the client.
- Log in.
- Close and reopen the client to prove session refresh.
- Read the profile.
- Update the profile.
- Create a post.
- Upload an image blob and create a post or record that references it.
- Confirm the write appears through `getLatestCommit`, `getRepo`, and the
  firehose.
- Confirm admin routes still reject normal account tokens.

## Admin Account Migration Gate

Only after the checks above pass:

1. Export the old PDS repo CAR.
2. Request service auth from the old PDS for account creation on Tempest.
3. Create the inactive account on Tempest.
4. Import the CAR.
5. Upload missing blobs.
6. Run `checkAccountStatus`.
7. Update identity so `#atproto_pds` points at Tempest.
8. Verify public DID and handle resolution again.
9. Activate the account.
10. Keep the old account undeleted through the validation window.

The migration procedure is described in
[Account Migration](./account-migration.md). The release gate is described in
[Initial Release Readiness](./release.md).

## Rollback

Before activation, rollback is deleting or ignoring the Tempest staging account.
The old PDS remains authoritative.

After identity update, rollback means moving the DID document back to the old PDS
and waiting for caches to settle. Keep the latest Tempest backup archive outside
Railway, and keep old-PDS credentials available until the new deployment has
passed the validation window.
