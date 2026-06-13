# Tempest deployment config

This directory contains runnable deployment examples for a production Phoenix
release:

- `Dockerfile` builds a release image.
- `docker-entrypoint.sh` creates the durable storage layout, bootstraps SQLite,
  runs Ecto migrations, then starts the release.
- `docker-compose.yml` runs Tempest locally, with an optional `proxy` profile for
  Caddy.
- `Caddyfile` is mounted by compose as `/etc/caddy/Caddyfile` when the proxy
  profile is enabled.
- `.env.example` is the single production env template for compose, releases,
  and PaaS secret managers.
  Copy it to `.env` and replace placeholders before running compose.

## Docker Checks (Local)

### Build release image

```bash
docker build -f conf/Dockerfile -t tempest:deploy-conf-smoke .
```

### Validate compose config

```bash
docker compose -f conf/docker-compose.yml config
```

### Validate compose config with Caddy profile

```bash
TEMPEST_HOSTNAME=tempest.example.com \
  docker compose -f conf/docker-compose.yml --profile proxy config
```

### Smoke test the built container

```bash
docker rm -f tempest-deploy-smoke >/dev/null 2>&1 || true

SECRET_KEY_BASE=$(mix phx.gen.secret)

docker run -d --name tempest-deploy-smoke \
  -e SECRET_KEY_BASE="$SECRET_KEY_BASE" \
  -e TEMPEST_HOSTNAME=localhost \
  -e TEMPEST_PUBLIC_URL=http://localhost:4000 \
  -e TEMPEST_DATA_DIR=/var/lib/tempest \
  -e TEMPEST_BLOB_MAX_BYTES=10000000 \
  -e TEMPEST_CRAWLERS= \
  -p 4000:4000 \
  -v tempest_deploy_smoke_data:/var/lib/tempest \
  tempest:deploy-conf-smoke
```

Then verify health and describeServer from outside the container:

```bash
curl -fsS http://127.0.0.1:4000/xrpc/_health
curl -fsS http://127.0.0.1:4000/xrpc/com.atproto.server.describeServer
```

Cleanup:

```bash
docker rm -f tempest-deploy-smoke
docker volume rm tempest_deploy_smoke_data
```
