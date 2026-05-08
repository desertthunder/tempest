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

Run the account/session smoke test with a fresh handle:

```bash
suffix="$(date +%s)"
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  --variable account_handle="smoke-${suffix}.test" \
  --variable account_email="smoke-${suffix}@example.com" \
  --variable account_password="correct horse battery staple" \
  test/smoke/accounts.hurl
```
