---
title: Initial Release Readiness
date: 2026-06-13
status: draft
---

Tempest is ready for an initial Railway staging deployment. It is not yet ready
for an irreversible migration of the main Bluesky account.

The app has enough release packaging, local protocol coverage, and storage documentation
to deploy it behind a stable HTTPS hostname. It still needs public-network proof before it
can become the authoritative PDS for the admin account.

## Plan

Proceed with a controlled Railway deployment using a single service, one mounted
volume at `/var/lib/tempest`, and Cloudflare R2 for blobs and backups.
Use [Deployment Guide](./deployment.md) for the step-by-step deployment path.

Do not activate the migrated admin account until all release gates pass:

- HTTPS health and XRPC checks pass against the final custom domain.
- WebSocket firehose works from outside Railway.
- DID and handle resolution point at the final `TEMPEST_PUBLIC_URL`.
- Relay/AppView crawl checks succeed.
- A backup can be created, downloaded, restored into a fresh volume, and used to
  boot a separate test service.
- A real client can log in, refresh a session, write a profile/post, upload and
  read a blob, and read the migrated repository.

## Tests

Local verification on 2026-06-13:

```text
mix precommit
Result: 292 passed
```

The precommit alias compiled with warnings as errors, checked unused
dependencies, formatted the codebase, and ran the test suite.

Docker Compose config renders cleanly:

```text
docker compose -f conf/docker-compose.yml config
```

The release image builds successfully:

```text
docker build -f conf/Dockerfile -t tempest:deploy-readiness .
```

The deployed HTTPS smoke file exists at `test/smoke/deployment.hurl`. It should
be run after the Railway service is reachable at the final hostname:

```bash
hurl --test --jobs 1 \
  --variable base_url=https://tempest.example.com \
  --variable admin_token="$ADMIN_TOKEN" \
  test/smoke/deployment.hurl
```

## Release Surface

- Phoenix release Dockerfile at `conf/Dockerfile`.
- Docker entrypoint at `conf/docker-entrypoint.sh` that creates the durable data
  layout, bootstraps storage, runs Ecto migrations, and starts the release.
- Production runtime config that reads Railway's `PORT`.
- Required production secrets and URL boundary in `conf/.env.example`.
- Budget Railway plus R2 profile in `docs/reference/budget.md`.
- Step-by-step Railway deployment guide in `docs/reference/deployment.md`.
- Deployment and observability notes in
  `docs/reference/deployment-observability.md`.
- Local PDS compatibility and migration lifecycle smoke coverage.
- Admin UI and admin JSON status for operator checks.

## Railway Conf

Use one Railway service and one volume.

Required service shape:

```text
replicas=1
volume mount=/var/lib/tempest
TEMPEST_DATA_DIR=/var/lib/tempest
```

Required variables:

```text
PHX_SERVER=true
SECRET_KEY_BASE=...
TEMPEST_HOSTNAME=<final bare hostname>
TEMPEST_PUBLIC_URL=https://<final bare hostname>
TEMPEST_DATA_DIR=/var/lib/tempest
TEMPEST_HOSTED_DID_METHOD=plc
TEMPEST_ADMIN_TOKEN_HASH=...
TEMPEST_BLOB_MAX_BYTES=10000000
TEMPEST_CRAWLERS=https://bsky.network,https://vsky.network
POOL_SIZE=5
```

Recommended for the first deployment:

```text
TEMPEST_BLOB_STORE=s3
TEMPEST_BACKUP_STORE=s3
TEMPEST_SMTP_ENABLED=false
```

Add the matching R2 endpoint, bucket, region, access key, and secret variables
for blob and backup storage.

Do not use a temporary Railway domain for account migration. It can prove the app
boots, but the admin account needs a stable hostname because DID documents,
handles, OAuth metadata, and relay crawlers depend on that URL.

## Admin Account Migration Plan

Use the admin account as the first real test bed only after staging passes.

1. Deploy Tempest to Railway with the final hostname.
2. Confirm `/xrpc/_health` and `com.atproto.server.describeServer` over HTTPS.
3. Confirm WebSocket access to `com.atproto.sync.subscribeRepos`.
4. Export the Bluesky-hosted repository CAR.
5. Request service auth from the old PDS for account creation on Tempest.
6. Create the Tempest account with the existing DID. It should start inactive.
7. Import the CAR.
8. Check `com.atproto.repo.listMissingBlobs`.
9. Upload missing blobs.
10. Check `com.atproto.server.checkAccountStatus`.
11. Update the DID document so `#atproto_pds` points at Tempest.
12. Re-check public DID and handle resolution from outside Railway.
13. Activate the Tempest account.
14. Deactivate the old PDS account only after the new account passes real-client
    login, write, blob, sync, and firehose checks.

This sequence follows the current AT Protocol migration flow: create an inactive
account on the new PDS with service auth, migrate repository and blobs, update
identity, then activate the new account.

## Release Checklist

The initial release can be called done when these are true:

- `mix precommit` passes from a clean worktree.
- `docker build -f conf/Dockerfile -t tempest:release .` passes.
- Railway deploy boots with the mounted volume.
- Railway health check and `test/smoke/deployment.hurl` pass against the final
  hostname.
- Admin status can be read with the admin token and rejects normal account
  tokens.
- R2 blob write/read works.
- R2 backup upload works.
- Restore drill succeeds against a fresh Railway volume or separate Railway test
  service.
- Public deployed checks pass for HTTPS, WebSocket, DID, handle, blob reads, and
  relay/AppView crawl.
- Real-client checks pass for login, session refresh, profile/post write, blob
  upload/read, and repo reads.

## Remaining Release Gates

- Run `test/smoke/deployment.hurl` against the final Railway hostname.
- Run `test/smoke/deployed/crawlers.hurl` against the final Railway hostname.
- Exercise the managed-volume plus R2 restore drill.
- Verify public DID and handle resolution from outside Railway.
- Complete the real-client login, session refresh, write, blob, and repo-read
  checklist.

The account migration reference also notes that full `did:plc` migration still
needs black-box migration-out coverage.

## Rollback

Before activation:

- The old Bluesky-hosted account remains authoritative.
- Tempest can be discarded or redeployed without public identity impact.

After identity update but before old-account deactivation:

- Keep both accounts accessible.
- Use `checkAccountStatus` on both sides.
- Keep the old account undeleted while caches settle.

After activation:

- Keep the latest Tempest backup archive outside Railway.
- Keep R2 blob and backup credentials recoverable.
- Do not delete the old account during the first validation window.

## External References Checked

- Railway Phoenix deployment guide, last updated 2026-06-01:
  <https://docs.railway.com/guides/phoenix>
- Railway volumes reference, last updated 2026-05-29:
  <https://docs.railway.com/volumes/reference>
- Railway pricing page checked 2026-06-13:
  <https://railway.com/pricing>
- AT Protocol account migration guide checked 2026-06-13:
  <https://atproto.com/guides/account-migration>
