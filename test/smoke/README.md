# Smoke Tests

These Hurl tests exercise Tempest through public HTTP endpoints.

Start the local server before running them:

```bash
mix phx.server
```

Run the health smoke test:

```bash
hurl --test --variable base_url=http://localhost:4000 test/smoke/health.hurl
```
