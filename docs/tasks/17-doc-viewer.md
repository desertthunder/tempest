---
title: Milestone 17 - Doc Viewer
specs:
  - ../specs/doc-viewer.md
  - ../specs/deployment-observability.md
references:
  - ../reference/README.md
  - ../reference/architecture.md
---

Goal: publish `docs/reference/` as a public Phoenix documentation site with a
Netscape Navigator-inspired shell and a web 1.0 design (with a sidebar & search)

- [x] T17-01: Add a `Tempest.Docs` context with a fixed manifest for files under
      `docs/reference/`.
- [x] T17-02: Add safe document lookup by slug. Reject unknown slugs and any path
      traversal attempt.
- [x] T17-03: Add frontmatter parsing for `title` and `updated`, falling back to
      manifest values when frontmatter is missing.
- [x] T17-04: Add server-side Markdown rendering for trusted local reference docs
      with `MDEx`
- [x] T17-05: Add relative-link rewriting for links between known reference docs.
- [x] T17-06: Add `TempestWeb.DocController` with `index` and `show` actions.
- [x] T17-07: Add public routes `GET /docs` and `GET /docs/:slug` under the
      browser pipeline.
- [x] T17-08: Add `TempestWeb.DocHTML` templates for the doc viewer.
- [x] T17-09: Build the Netscape-style chrome: title bar, toolbar buttons,
      location bar, bookmarks pane, document pane, and footer.
- [x] T17-10: Add responsive CSS through the existing vanilla CSS structure
      (`assets/css/app.css` plus component files such as
      `assets/css/components/doc-viewer.css`).
- [x] T17-11: Add accessible focus, contrast, heading, and navigation behavior.
- [x] T17-12: Add previous/next document links based on manifest order.
- [x] T17-13: Link the docs viewer from the home page and any relevant public
      navigation.
- [x] T17-14: Add ConnCase tests for `/docs`, `/docs/architecture`, unknown slugs,
      sidebar navigation, relative-link rewriting, and path traversal rejection.
- [x] T17-15: Add regression tests proving files outside `docs/reference/` cannot
      be rendered.
- [x] T17-16: Add Hurl smoke test `test/smoke/doc-viewer.hurl`.
- [x] T17-17: Add production caching

## Integration Tests

- Public docs routes work without authentication.
- The architecture reference document renders through the viewer.
- Sidebar/bookmarks include the manifest documents.
- Unknown slugs return 404.
- Path traversal does not read local files.
- Relative links between reference docs resolve to `/docs/:slug`.
- The page remains usable without JavaScript.

## HTTP Verification

```bash
curl -fsS http://localhost:4000/docs
curl -fsS http://localhost:4000/docs/architecture
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  test/smoke/doc-viewer.hurl
```

## Design Notes

The design should look like a real retro browser, not a generic docs template.
Required motifs:

- faux Netscape-style title bar
- beveled gray toolbar
- Back / Forward / Stop / Reload / Home / Search / Print controls
- `Location:` input-style path display
- left bookmarks pane
- main document pane
- blue underlined links
- dithered or tiled-feeling background texture
- "Best viewed in Tempest Navigator" footer copy

Keep it semantic and responsive. Do not use actual framesets. Do not use inline
scripts. Do not reference external vendored assets from layouts.
