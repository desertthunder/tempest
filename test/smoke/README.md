# Smoke Tests

Canonical smoke-test documentation lives in
[Interop & Integration Testing](../../docs/reference/interop-testing.md).

Local PDS compatibility profile:

```bash
mix phx.server

test/smoke/local-pds-compat.sh http://localhost:4000
```

Quick local run:

```bash
mix phx.server

suffix="$(date +%s)"
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  --variable suffix="${suffix}" \
  --variable account_handle="smoke-${suffix}.test" \
  --variable account_email="smoke-${suffix}@example.com" \
  --variable account_password="correct horse battery staple" \
  test/smoke/health.hurl \
  test/smoke/xrpc.hurl \
  test/smoke/accounts.hurl \
  test/smoke/identity.hurl \
  test/smoke/records.hurl \
  test/smoke/car-sync.hurl \
  test/smoke/firehose.hurl \
  test/smoke/blobs.hurl \
  test/smoke/lexicon-schemas.hurl \
  test/smoke/migration-lifecycle.hurl \
  test/smoke/oauth-security.hurl \
  test/smoke/operator-account-ux.hurl \
  test/smoke/tempest_basic.hurl \
  test/smoke/tempest_compat.hurl
```

Use fresh account variables for every run. Some files create accounts with the
same variables, so run those files separately if the shared handle already exists.

`test/smoke/deployment.hurl` is deployed-only. Run it against the final HTTPS
hostname with an admin token:

```bash
hurl --test --jobs 1 \
  --variable base_url=https://tempest.example.com \
  --variable admin_token="$ADMIN_TOKEN" \
  test/smoke/deployment.hurl
```
