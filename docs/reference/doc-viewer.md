---
title: Documentation Viewer
updated: 2026-06-19
---

Tempest publishes the project reference documentation as a public, browsable
Phoenix LiveView. The source of truth remains Markdown under `docs/reference/`;
the web UI is a deliberately constrained reader with a Web 1.0 / Netscape
Navigator-inspired interface.

## Public routes

```text
GET /docs
GET /docs/:slug
```

`/docs` renders the reference index from `docs/reference/README.md`. Other routes
map only to slugs in the fixed `Tempest.Docs` manifest, such as:

```text
/docs/architecture
/docs/storage-sqlite
/docs/pds-compatibility
```

Unknown slugs return 404. Path traversal attempts and raw file names such as
`architecture.md` are rejected before any file read.

## Manifest boundary

`Tempest.Docs` owns a fixed manifest of publishable reference files. The route
parameter is a slug, not a path. A document is public only if it appears in that
manifest.

The manifest also defines sidebar order and previous/next navigation. It includes
every Markdown file under `docs/reference/`, and the test suite compares the
manifest to the directory contents so new reference docs must be deliberately
published.

## Rendering model

Reference Markdown is trusted maintainer-authored project content. Tempest renders
it server-side with MDEx and supports headings, links, fenced code blocks, tables,
lists, inline code, and blockquotes.

Each document may include simple frontmatter:

```yaml
---
title: Architecture
updated: 2026-06-03
---
```

If frontmatter is missing, the viewer falls back to manifest metadata.

Only trusted local reference files are rendered. The viewer never renders
request-provided Markdown and never accepts arbitrary document paths.

## Link rewriting

Relative links between known reference docs are rewritten to viewer routes:

```text
./architecture.md             -> /docs/architecture
../reference/architecture.md  -> /docs/architecture
identity-troubleshooting.md   -> /docs/identity-troubleshooting
```

External `http://` and `https://` links remain external. Links to specs, tasks,
or files outside `docs/reference/` are not part of the public docs viewer
contract.

## Interface

The UI uses the existing vanilla CSS bundle and the dedicated
`assets/css/components/doc-viewer.css` component stylesheet. It is semantic HTML
with a retro browser shell:

- title bar and beveled toolbar;
- Back, Forward, Stop, Reload, Home, Search, and Print controls;
- `Location:` path display;
- left bookmarks pane;
- main document pane;
- previous/next document links;
- footer copy for the Tempest Navigator motif.

The page remains usable without JavaScript. The visual treatment references old
browser chrome, but it does not use real framesets or inline scripts.

## Caching

Docs are static project files. The current policy is:

- `dev`: read every request for fast documentation iteration;
- `test`: read every request;
- `prod`: cache successfully rendered manifest documents in `:persistent_term`.

Route params that are not in the manifest are never cached.

## Verification

```bash
curl -fsS http://localhost:4000/docs
curl -fsS http://localhost:4000/docs/architecture
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  test/smoke/doc-viewer.hurl
```

Focused tests cover unauthenticated rendering, sidebar content, relative-link
rewriting, path traversal rejection, unknown slugs, sample Markdown features, and
the guarantee that files outside `docs/reference/` cannot be rendered.
