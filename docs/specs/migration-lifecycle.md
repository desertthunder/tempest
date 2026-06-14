---
title: Migration and Account Lifecycle
updated: 2026-05-31
status: implemented
---

Reference documentation: ../reference/migration-lifecycle.md

Verification:

```bash
mix test
hurl --test --jobs 1 --variable base_url=http://localhost:4000 \
  test/smoke/migration-lifecycle.hurl
```

See the reference doc for detailed lifecycle semantics and the public identity
migration caveats.
