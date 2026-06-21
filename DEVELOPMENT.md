# Tempest Development

Tempest is a Phoenix application that can run locally without Docker, Postgres,
or a reverse proxy. The default development profile uses SQLite and filesystem
storage under `priv/tempest_dev`.

## Prerequisites

- Elixir and Erlang/OTP compatible with `mix.exs`
- `mix`
- `hurl` for smoke tests
- Docker or Podman only when testing release/compose behavior
- `uv` only when using the helper scripts in `scripts/`

## First Run

```bash
mix setup
mix phx.server
```

Open `http://localhost:4000`.

`mix setup` runs dependency install, storage bootstrap, Ecto migrations, seeds,
and asset setup/build. Server boot creates or reuses:

- `priv/tempest_dev/account.sqlite`
- `priv/tempest_dev/sequencer.sqlite`
- `priv/tempest_dev/repos/`
- `priv/tempest_dev/blobs/`
- `priv/tempest_dev/tmp/`
- `priv/tempest_dev/backups/`

Development email previews are available at
`http://localhost:4000/dev/mailbox`.

## Local Configuration

The built-in development defaults are:

```bash
TEMPEST_HOSTNAME=localhost
TEMPEST_PUBLIC_URL=http://localhost:4000
TEMPEST_DATA_DIR=/absolute/path/to/tempest/priv/tempest_dev
TEMPEST_BLOB_MAX_BYTES=10000000
TEMPEST_HOSTED_DID_METHOD=plc
TEMPEST_CRAWLERS=https://bsky.network,https://vsky.network
```

Override only what you need. `TEMPEST_DATA_DIR` must be absolute, and
`TEMPEST_PUBLIC_URL` must use the same host as `TEMPEST_HOSTNAME`.

For a disposable local profile:

```bash
export TEMPEST_HOSTNAME=localhost
export TEMPEST_PUBLIC_URL=http://localhost:4000
export TEMPEST_DATA_DIR="$PWD/priv/tempest_dev"
export TEMPEST_BLOB_STORE=local
export TEMPEST_BACKUP_STORE=local
mix phx.server
```

To bind a different port:

```bash
PORT=4001 TEMPEST_PUBLIC_URL=http://localhost:4001 mix phx.server
```

## Accounts

Local development does not require invite codes.

Create accounts through the following XRPC method:

```bash
curl -fsS http://localhost:4000/xrpc/com.atproto.server.createAccount \
  -H 'content-type: application/json' \
  --data '{"handle":"alice.test","email":"alice@example.com","password":"correct horse battery staple"}'
```

Use fresh handles when re-running smoke tests against the same data directory.

## Admin Development

Browser admin access is tied to `TEMPEST_ADMIN_DID`. A practical local flow is:

1. Create a normal local account.
2. Copy its `did` from the `createAccount` response.
3. Restart the server with `TEMPEST_ADMIN_DID=<that did>`.
4. Visit `http://localhost:4000/admin/login` and sign in with that account's
   handle or DID and password.

The admin bearer token path is optional and mainly useful for automation such as
`/xrpc/_admin/status`.

Generate a raw token and hash:

```bash
uv run --project scripts tempest argon
```

Keep the raw token outside the repo, then set only the printed
`TEMPEST_ADMIN_TOKEN_HASH` value in the environment. Argon2 hashes contain `$`,
so prefer a process manager, compose env file, or secret manager over shell
copy/paste.

## Tests

Run the normal Elixir suite:

```bash
mix test
```

Before finishing Elixir changes, run the project precommit alias:

```bash
mix precommit
```

### Smoke Checks

Tempest's smoke checks are executable HTTP transcripts, not shell wrappers around
implementation details. They run against a live server through public routes and
assert protocol-shaped behavior at the same boundary used by SDKs, relays,
AppViews, and operators.

Use them to catch regressions that unit tests can miss:

- content type and status-code drift
- AT Protocol JSON error shape regressions
- auth boundary mistakes between public, bearer, and admin routes
- repo/CAR/blob/firehose behavior that only appears over HTTP or WebSocket
- account/session flows that depend on state created by earlier XRPC calls
- deployed-only assumptions around HTTPS, public DNS, relays, and admin tokens

Run account-creating smoke tests serially with `--jobs 1` and fresh account
variables. Hurl files are readable request transcripts, so prefer adding a new
`.hurl` flow when a behavior matters at the PDS boundary.

Run the local PDS compatibility smoke profile against a running server:

```bash
mix phx.server
test/smoke/local-pds-compat.sh http://localhost:4000
```

That profile is the fast compatibility gate. It covers Tempest's baseline PDS
flow, compatibility hardening, OAuth/security metadata, and migration lifecycle
checks without requiring a public hostname.

For a broader local smoke pass:

```bash
suffix="$(date +%s)"
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  --variable suffix="${suffix}" \
  --variable account_handle="smoke-${suffix}.test" \
  --variable account_email="smoke-${suffix}@example.com" \
  --variable account_password="correct horse battery staple" \
  test/smoke/health.hurl \
  test/smoke/public-stats.hurl \
  test/smoke/xrpc.hurl \
  test/smoke/accounts.hurl \
  test/smoke/records.hurl \
  test/smoke/car-sync.hurl \
  test/smoke/firehose.hurl \
  test/smoke/blobs.hurl \
  test/smoke/lexicon-schemas.hurl \
  test/smoke/oauth-security.hurl \
  test/smoke/tempest_basic.hurl \
  test/smoke/tempest_compat.hurl
```

Do not run `test/smoke/*.hurl` as a wildcard. Some smoke tests are
deployed-only or need specific account/admin variables.

Use the deployed smoke checks only against a public HTTPS origin:

```bash
hurl --test --jobs 1 \
  --variable base_url=https://tempest.example.com \
  --variable admin_token="$ADMIN_TOKEN" \
  test/smoke/deployment.hurl
```

Relay crawler checks are deployed-only because real relays reject localhost and
private hostnames:

```bash
hurl --test --jobs 1 \
  --variable base_url=https://tempest.example.com \
  --variable crawler_hostname=tempest.example.com \
  test/smoke/deployed/crawlers.hurl
```

See [`test/smoke/README.md`](./test/smoke/README.md) and
[`docs/reference/interop-testing.md`](./docs/reference/interop-testing.md) for
the maintained smoke-test inventory.

## Container and Proxy Parity

Use `conf/` when you need to exercise the release image or reverse proxy path.

```bash
cp conf/.env.example conf/.env
docker compose -f conf/docker-compose.yml up --build
```

The compose service stores data in `data/tempest` and exposes
`http://localhost:4000`.

To validate the Caddy profile:

```bash
TEMPEST_HOSTNAME=tempest.example.com \
  docker compose -f conf/docker-compose.yml --profile proxy config
```

Run the proxy profile only with a hostname that resolves to the machine running
Caddy. Like the official PDS deployment, Caddy handles HTTPS and WebSocket
upgrades without extra route-specific directives.

## Public-Hostname Testing

Real federation checks need public DNS and HTTPS. Localhost is enough for unit,
Phoenix integration, and most Hurl coverage, but relays and real clients need a
reachable hostname.

Use public-hostname testing when checking:

- DID documents and handle resolution from outside the machine
- OAuth callback/client metadata behavior with a real origin
- relay crawling via `requestCrawl`
- WebSocket behavior through a reverse proxy
- deployed blob URLs or CDN redirects

Other PDS projects often solve this with compose plus Caddy, Traefik, local PLC,
and mail sinks. Tempest currently documents only the production-like Caddy
compose path in `conf/`; keep ad hoc local tunnels or fake domains out of the
default setup unless they become part of a committed test profile.

## Resetting Local State

For a clean development database and storage tree:

```bash
mix ecto.reset
```

If you changed `TEMPEST_DATA_DIR`, make sure the same environment is set when
running reset. The reset task bootstraps the Tempest storage layout before
migrating.

For a fully disposable run, point `TEMPEST_DATA_DIR` at a temporary absolute
directory and delete that directory when finished.

## Useful Routes

Account operator UI:

```text
/account
/account/repo
/account/blobs
/account/access
/account/security
/account/migration
/account/sequencer
/account/firehose
```

Admin UI:

```text
/admin/login
/admin/logout
/admin
/admin/accounts
/admin/invites
/admin/repo
/admin/backups
/admin/storage
/admin/compatibility
/xrpc/_admin/status
```

Health and metadata:

```text
/xrpc/_health
/xrpc/com.atproto.server.describeServer
/.well-known/atproto-did
```
