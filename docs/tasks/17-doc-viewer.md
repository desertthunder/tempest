---
title: Milestone 17 - Doc Viewer
specs:
  - ../specs/doc-viewer.md
  - ../specs/deployment-observability.md
references:
  - ../reference/README.md
  - ../reference/architecture.md
---

Completed [June 19, 2026](../../CHANGELOG.md#2026-06-14).

## Verification

```bash
curl -fsS http://localhost:4000/docs
curl -fsS http://localhost:4000/docs/architecture
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  test/smoke/doc-viewer.hurl
```

The viewer publishes the fixed `docs/reference/` manifest through `/docs` and
`/docs/:slug`, renders trusted local Markdown, rewrites known reference links,
rejects unknown/path-traversal slugs, and keeps the retro browser shell usable
without JavaScript.

Reference documentation: [Documentation Viewer](../reference/doc-viewer.md).
