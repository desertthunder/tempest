# Tempest

Tempest is a self-hostable AT Protocol Personal Data Server (PDS) built with
Elixir and Phoenix.

![UI](./docs/images/ui.png)

## PDS Completion TODO

The current endpoint matrix/coverage is in the [`pds compatibility`](docs/reference/pds-compatibility.md) doc.

## Run Locally

```bash
mix setup
mix phx.server
```

The development server runs at `http://localhost:4000`.

Default development config uses `localhost`, `http://localhost:4000`, `priv/tempest_dev`,
and a 10 MB blob limit.

Override with:

```bash
TEMPEST_HOSTNAME=localhost
TEMPEST_PUBLIC_URL=http://localhost:4000
TEMPEST_DATA_DIR=/absolute/path/to/tempest/priv/tempest_dev
TEMPEST_BLOB_MAX_BYTES=10000000
TEMPEST_HOSTED_DID_METHOD=plc
TEMPEST_CRAWLERS=https://bsky.network,https://vsky.network
TEMPEST_ADMIN_DID=did:plc:...
TEMPEST_ADMIN_TOKEN_HASH="$argon2id$v=19$..."
```

Server boot creates `account.sqlite`, `sequencer.sqlite`, and local storage directories
inside `TEMPEST_DATA_DIR`.

## Admin Configuration

Browser admin access is anchored to `TEMPEST_ADMIN_DID`.

When that DID belongs to a local Tempest account, `/admin/login` accepts the
account handle or DID plus the account password and stores only a server-side
admin session reference in the browser session.

`TEMPEST_ADMIN_TOKEN_HASH` is optional and is reserved for bootstrap and
automation paths such as `/xrpc/_admin/status`. It should be stored as an Argon2 hash.

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

Admin UI:

```text
/admin/login
/admin/logout
/admin
/admin/accounts
/admin/accounts/:did
/admin/invites
/admin/repo
/admin/backups
/admin/storage
/admin/compatibility
/xrpc/_admin/status
```

To generate a TOTP code for a base32 secret:

```bash
mix tempest.totp.code <base32-secret>
```

Development email previews are available at `http://localhost:4000/dev/mailbox`
when the server is running.

## Endpoints

See the maintained compatibility matrix:

- [`docs/reference/pds-compatibility.md`](docs/reference/pds-compatibility.md)
- Admin UI: `/admin/compatibility`

## Docs

You can also view docs on the [deployed instance](https://tempest.desertthunder.dev/docs)
and copy the markdown.

![Docs as Netscape Navigator](docs/images/docs.png)

### Changelog

You can view the changelog in [this repo](./CHANGELOG.md) or [live](https://tempest.desertthunder.dev/changelog)
as a word processor.

![CHANGELOG as a Word Doc](docs/images/changelog.png)

## Credits

- [Cocoon](https://github.com/haileyok/cocoon) - a PDS written in Go
- [Tranquil](https://tangled.org/tranquil.farm/tranquil-pds) - a PDS written in Rust
- [ZDS](https://tangled.org/zat.dev/zds) - a PDS written in Zig
- [PDS Reference Implementation](https://github.com/bluesky-social/atproto/tree/main/packages/pds)
