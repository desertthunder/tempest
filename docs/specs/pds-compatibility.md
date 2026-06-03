---
title: PDS Compatibility Against Reference Surface
updated: 2026-06-03
status: implemented
---

Reference documentation: ../reference/pds-compatibility.md

Verification:

```bash
mix test
hurl --test --jobs 1 --variable base_url=http://localhost:4000 test/smoke/
```

When running the full smoke directory, pass unique account variables as described
in `test/smoke/README.md`.
