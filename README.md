# Tempest

Tempest is a self-hostable AT Protocol Personal Data Server (PDS) built with
Elixir and Phoenix.

## PDS Completion TODO

- [ ] Firehose: durable sequencing, CAR slices, cursor backfill, and `subscribeRepos`.
- [ ] Blobs: upload, validate, serve, list, reference-check, and garbage collect.
- [ ] Lexicons: generated pinned schemas and broader endpoint/record validation.
- [ ] Compatibility: official fixtures, SDK smoke tests, rate limits, and relay/AppView checks.
- [ ] Auth and operations: OAuth, app passwords, admin tools, repo import/export/verify, and backups.
- [ ] Deployment: release packaging, Docker/Compose, HTTPS proxy docs, telemetry, and SMTP.

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

Generate a TOTP code for a base32 secret:

```bash
mix tempest.totp.code <base32-secret>
```

Development email previews are available at `http://localhost:4000/dev/mailbox`
when the server is running.

## Endpoints

Available as of [2026-05-08](./CHANGELOG.md#2026-05-08)

- `GET /xrpc/_health`
- `GET /xrpc/com.atproto.server.describeServer`
- `POST /xrpc/com.atproto.server.createAccount`
- `POST /xrpc/com.atproto.server.createSession`
- `GET /xrpc/com.atproto.server.getSession`
- `POST /xrpc/com.atproto.server.refreshSession`
- `POST /xrpc/com.atproto.server.deleteSession`
- `GET /xrpc/com.atproto.identity.resolveHandle`
- `POST /xrpc/com.atproto.identity.updateHandle`
- `GET /.well-known/atproto-did`
- `POST /xrpc/com.atproto.repo.createRecord`
- `POST /xrpc/com.atproto.repo.putRecord`
- `POST /xrpc/com.atproto.repo.deleteRecord`
- `GET /xrpc/com.atproto.repo.getRecord`
- `GET /xrpc/com.atproto.repo.listRecords`
- `GET /xrpc/com.atproto.repo.describeRepo`
- `GET /xrpc/com.atproto.sync.getRepo`
- `GET /xrpc/com.atproto.sync.getLatestCommit`
- `GET /xrpc/com.atproto.sync.getRecord`
- `GET /xrpc/com.atproto.sync.getBlocks`
- `GET /xrpc/com.atproto.sync.getRepoStatus`
- `GET /xrpc/com.atproto.sync.listRepos`
- `GET /xrpc/com.atproto.sync.listBlobs`

## Credits

- [Cocoon](https://github.com/haileyok/cocoon) - a PDS written in Go
- [Tranquil](https://tangled.org/tranquil.farm/tranquil-pds) - a PDS written in Rust
- [PDS Reference Implementation](https://github.com/bluesky-social/atproto/tree/main/packages/pds)
