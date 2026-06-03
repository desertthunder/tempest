# Tempest

Tempest is a self-hostable AT Protocol Personal Data Server (PDS) built with
Elixir and Phoenix.

## PDS Completion TODO

The current endpoint matrix/coverage is [`docs/reference/pds-compatibility.md`](docs/reference/pds-compatibility.md).

## Run Locally

```bash
mix setup
mix phx.server
```

The development server runs at `http://localhost:4000`.

Default development config uses `localhost`, `http://localhost:4000`, `priv/tempest_dev`, and a 10 MB blob limit.
Override with:

```bash
TEMPEST_HOSTNAME=localhost
TEMPEST_PUBLIC_URL=http://localhost:4000
TEMPEST_DATA_DIR=/absolute/path/to/tempest/priv/tempest_dev
TEMPEST_BLOB_MAX_BYTES=10000000
TEMPEST_HOSTED_DID_METHOD=plc
```

Server boot creates `account.sqlite`, `sequencer.sqlite`, and local storage directories inside `TEMPEST_DATA_DIR`.

## Development Tools

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

Admin UI and status, using `Authorization: Bearer $ADMIN_TOKEN`:

```text
/admin
/admin/storage
/admin/compatibility
/xrpc/_admin/status
```

Generate a TOTP code for a base32 secret:

```bash
mix tempest.totp.code <base32-secret>
```

Development email previews are available at `http://localhost:4000/dev/mailbox`
when the server is running.

## Endpoints

See the maintained compatibility matrix:

- [`docs/reference/pds-compatibility.md`](docs/reference/pds-compatibility.md)
- Admin UI: `/admin/compatibility`

## Credits

- [Cocoon](https://github.com/haileyok/cocoon) - a PDS written in Go
- [Tranquil](https://tangled.org/tranquil.farm/tranquil-pds) - a PDS written in Rust
- [PDS Reference Implementation](https://github.com/bluesky-social/atproto/tree/main/packages/pds)
