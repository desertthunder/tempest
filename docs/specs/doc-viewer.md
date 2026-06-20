---
title: Documentation Viewer
updated: 2026-06-19
status: implemented
---

Reference documentation: ../reference/doc-viewer.md

## HTTP verification

```bash
curl -fsS http://localhost:4000/docs
curl -fsS http://localhost:4000/docs/architecture
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  test/smoke/doc-viewer.hurl
```
