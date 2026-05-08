# Tempest

A self-hostable AT Protocol Personal Data Server (PDS) built in Elixir for single-users
or small communities.

## PDS Completion TODO

- [ ] Sync: CAR export, latest commit/status reads, and `subscribeRepos`.
- [ ] Blobs: upload, validate, serve, list, reference-check, and garbage collect.
- [ ] Lexicons: generate pinned AT Protocol schemas and validate supported records/endpoints.
- [ ] Auth/operations: token hardening, app passwords, admin tools, repo import/export/verify,
      and backups.
- [ ] Deployment: release packaging, Docker/Compose, HTTPS proxy docs, telemetry, and SMTP.
- [ ] Compatibility: official fixtures, SDK smoke tests, rate limits, and relay/AppView checks.

## Local Server

Start the Phoenix server:

```bash
mix phx.server
```

Server boot creates `account.sqlite`, `sequencer.sqlite`, and local storage directories
inside `TEMPEST_DATA_DIR` when they do not exist.

By default, development uses `localhost`, `http://localhost:4000`, a data directory under
`priv/tempest_dev`, and a 10 MB blob limit. Override those settings with:

```bash
TEMPEST_HOSTNAME=localhost
TEMPEST_PUBLIC_URL=http://localhost:4000
TEMPEST_DATA_DIR=/absolute/path/to/tempest/priv/tempest_dev
TEMPEST_BLOB_MAX_BYTES=10000000
```

Run smoke tests with [hurl](https://hurl.dev/). See the [smoke test](./test/smoke/README.md)
module for more details.
