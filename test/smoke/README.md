# Smoke Tests

Canonical smoke-test documentation lives in
[`docs/reference/interop-testing.md`](../../docs/reference/interop-testing.md).

Quick run:

```bash
mix phx.server

suffix="$(date +%s)"
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  --variable suffix="${suffix}" \
  --variable account_handle="smoke-${suffix}.test" \
  --variable account_email="smoke-${suffix}@example.com" \
  --variable account_password="correct horse battery staple" \
  test/smoke/
```

Use fresh account variables for every run. Some files create accounts with the
same variables, so run those files separately if the shared handle already exists.
