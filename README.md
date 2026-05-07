# Tempest

A self-hostable AT Protocol Personal Data Server (PDS) built in Elixir for single-users
or small communities.

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

Run the foundation smoke test with Hurl:

```bash
hurl --test --variable base_url=http://localhost:4000 test/smoke/health.hurl
```
