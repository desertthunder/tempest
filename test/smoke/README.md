# Smoke Tests

Canonical smoke-test documentation lives in
[Interop & Integration Testing](../../docs/reference/interop-testing.md).

## Quick local run

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
  test/smoke/public-stats.hurl \
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

## Local PDS compatibility profile

```bash
mix phx.server

test/smoke/local-pds-compat.sh http://localhost:4000
```

## Deployed-only files

`test/smoke/deployment.hurl` - non-destructive HTTPS checks with an admin token:

```bash
hurl --test --jobs 1 \
  --variable base_url=https://tempest.example.com \
  --variable admin_token="$ADMIN_TOKEN" \
  test/smoke/deployment.hurl
```

`test/smoke/deployed/crawlers.hurl` - relay crawl request against configured relays:

```bash
hurl --test --jobs 1 \
  --variable base_url=https://tempest.example.com \
  --variable crawler_hostname=tempest.example.com \
  test/smoke/deployed/crawlers.hurl
```

## Files needing special variables

### email-security.hurl

Requires an operator-supplied `reset_token`. The token is obtained out-of-band
because Tempest never returns raw tokens in API responses. In dev, extract it
from the Swoosh mailbox preview; in production, from Resend's event log.

```bash
# Create account and request reset
suffix="$(date +%s)"
email="email-security-${suffix}@example.com"
password="correct horse battery staple"

curl -sf -X POST http://localhost:4000/xrpc/com.atproto.server.createAccount \
  -H "Content-Type: application/json" \
  -d "{\"handle\":\"email-smoke-${suffix}.test\",\"email\":\"${email}\",\"password\":\"${password}\"}" > /dev/null

curl -sf -X POST http://localhost:4000/xrpc/com.atproto.server.requestPasswordReset \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${email}\"}" > /dev/null

# Extract token from dev mailbox
sleep 1
eid=$(curl -sf http://localhost:4000/dev/mailbox | grep -oE '/dev/mailbox/[a-f0-9]+' | head -1 | sed 's|/dev/mailbox/||')
token=$(curl -sf "http://localhost:4000/dev/mailbox/${eid}" | grep -oE '[A-Za-z0-9_-]{43,}' | tail -1)

hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  --variable account_email="${email}" \
  --variable account_password="${password}" \
  --variable reset_token="${token}" \
  test/smoke/email-security.hurl
```

### identity-correctness.hurl

Requires a pre-created account with captured `handle`, `access`, and `did`
variables. The test creates the account internally but the assertions reference
external variables, so all three must be supplied.

### account-management-admin.hurl

Requires `admin_did`, `admin_identifier`, and `admin_password` for an admin
account configured via `TEMPEST_ADMIN_DID`. Cannot run without admin auth set up.

### account-management.hurl and operator-account-ux.hurl

Both need a `suffix` variable to generate unique handles. No other variables
required beyond `base_url` and `suffix`.
