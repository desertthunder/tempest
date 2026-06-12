---
title: Documentation Viewer
updated: 2026-06-12
status: planned
---

Tempest should expose the project reference documentation as a public, browsable
site. The source of truth remains Markdown under `docs/reference/`; the web UI is
a Phoenix-rendered viewer with a deliberate Web 1.0 / Netscape Navigator-inspired
interface.

Reference source:

- [Reference Documentation](../reference/README.md)
- [Architecture](../reference/architecture.md)
- [Deployment and Observability](../reference/deployment-observability.md)
- [PDS Compatibility Matrix](../reference/pds-compatibility.md)

## Goals

- Publish `docs/reference/*.md` through the web app without duplicating content.
- Keep Markdown files useful in git, editors, and rendered docs.
- Provide a memorable "Netscape Navigator for a tiny PDS" UI.
- Make the docs easy to scan: navigation tree, document title, updated date,
  headings, tables, code blocks, and previous/next links.
- Keep the implementation safe: no arbitrary file reads, no path traversal, no
  rendering user-supplied Markdown.
- Avoid heavy client-side behavior. This should work without JavaScript.

## Non-goals

- No CMS or browser editing in the first version.
- No public access to admin-only operational data.
- No runtime fetching of remote documentation.
- No real HTML framesets. The UI may visually reference frames, but should use
  normal semantic HTML and responsive CSS.
- No inline scripts in templates.

## Public routes

Preferred routes:

```text
GET /docs
GET /docs/:slug
```

`/docs` should redirect to or render the reference index from
`docs/reference/README.md`.

`/:slug` should map only to known reference document slugs. Examples:

```text
/docs/architecture
/docs/storage-sqlite
/docs/pds-compatibility
```

Unknown slugs should return a normal 404 page.

## Content source and manifest

Use a fixed manifest rather than accepting arbitrary paths from route params.
The manifest can be a module attribute in a context such as `Tempest.Docs`:

```elixir
@documents [
  %{slug: "architecture", path: "architecture.md", title: "Architecture"},
  %{slug: "storage-sqlite", path: "storage-sqlite.md", title: "SQLite Storage"},
  %{slug: "xrpc", path: "xrpc.md", title: "XRPC HTTP Surface"}
]
```

The manifest should include every intended file from `docs/reference/`. It should
also define display order for sidebar and previous/next navigation.

The viewer may parse YAML-ish frontmatter for `title` and `updated`, but should
not require frontmatter to render. If frontmatter is missing, derive a title from
the manifest.

## Markdown rendering

The first implementation should use a server-side Markdown renderer that supports:

- headings
- links
- fenced code blocks
- tables
- lists
- inline code
- blockquotes

Implementation options:

1. Add a Markdown library such as `MDEx` or `Earmark` and render trusted local
   docs on the server.
2. If avoiding a dependency is preferred, render only a conservative subset in a
   small local parser. This is lower capability and should not be the default if
   tables/code fences become painful.

Because the input files are trusted project files, rendering can allow normal
Markdown HTML output. Still, the implementation must never render arbitrary
request-provided file contents. If raw HTML in Markdown is enabled, document that
it is trusted-maintainer-only content.

## Link handling

Relative links between reference docs should become viewer links where possible:

```text
./architecture.md          -> /docs/architecture
../reference/architecture.md -> /docs/architecture
identity-troubleshooting.md -> /docs/identity-troubleshooting
```

External `http://` and `https://` links should remain external and include clear
visual treatment.

Links to specs, tasks, or files outside `docs/reference/` may either:

- link to the raw repository path if a public source URL is configured later; or
- remain non-clickable with a `title` explaining that only reference docs are
  published in the first version.

## Visual design: Web 1.0 Netscape Navigator

The UI should feel like a lovingly restored 1990s documentation browser, not a
modern SaaS docs template.

Required visual motifs:

- a faux browser chrome header with a title bar
- toolbar buttons: Back, Forward, Stop, Reload, Home, Search, Print; they may be
  decorative or normal links where useful
- a `Location:` bar showing the current `/docs/...` path
- a left "Bookmarks" pane listing reference docs
- a main document pane with beveled borders
- gray system-window surfaces, inset/outset borders, tiled or dithered textures
- blue underlined links and visited-link styling
- compact metadata strip with title, updated date, and document slug
- optional footer details such as "Best viewed in Tempest Navigator" and a static
  build/version badge

The aesthetic should be playful, but the content must stay readable. Use the
project's current vanilla CSS structure responsibly. Add a dedicated component
stylesheet, for example `assets/css/components/doc-viewer.css`, and import it from
`assets/css/app.css`.

- semantic HTML first
- responsive layout that collapses the bookmarks pane below or above content on
  narrow screens
- accessible contrast despite retro colors
- visible keyboard focus states
- no marquee for important content
- no layout implemented with actual HTML tables unless used for document content

## Suggested layout

```text
+-----------------------------------------------------------------+
| Tempest Navigator 4.0 - Reference Documentation                 |
+-----------------------------------------------------------------+
| [Back] [Forward] [Stop] [Reload] [Home] [Search] [Print]        |
| Location: http://tempest.local/docs/architecture                |
+-------------------------+---------------------------------------+
| Bookmarks               | Architecture                          |
| * Architecture          | updated: 2026-06-03                   |
| * SQLite Storage        |                                       |
| * XRPC                  | Markdown-rendered reference doc...    |
| * Repo Core             |                                       |
+-------------------------+---------------------------------------+
| Best viewed in Tempest Navigator | version ... | /xrpc/_health  |
+-----------------------------------------------------------------+
```

## Phoenix implementation notes

Recommended modules:

- `Tempest.Docs` context for manifest lookup, file loading, frontmatter parsing,
  Markdown rendering, and link rewriting.
- `TempestWeb.DocController` for `index` and `show` actions.
- `TempestWeb.DocHTML` with `index.html.heex` or `show.html.heex`.

Recommended route placement:

```elixir
scope "/", TempestWeb do
  pipe_through :browser

  get "/docs", DocController, :index
  get "/docs/:slug", DocController, :show
end
```

The controller should pass assigns such as:

- `:documents`
- `:document`
- `:html`
- `:previous_document`
- `:next_document`

When rendering generated HTML in HEEx, only output trusted converted docs. Use a
clear boundary function so reviewers can see where HTML safety is decided.

## Caching

Docs are static project files. Initial implementation can read at request time in
`dev` and cache in memory in `prod`. A later version can add ETags or a manifest
checksum.

A simple first-pass policy:

- `dev`: read every request for fast documentation iteration
- `test`: read every request
- `prod`: cache rendered docs in `:persistent_term` or a supervised GenServer

Do not cache route params that are not in the manifest.

## Tests

Required test coverage:

- `/docs` renders without authentication.
- `/docs/architecture` renders the architecture reference doc.
- unknown slug returns 404.
- path traversal attempts fail, e.g. `/docs/..%2F..%2Fconfig%2Fprod.exs`.
- sidebar contains known reference docs.
- rendered document includes headings, code blocks, and tables from sample docs.
- private/admin docs or paths outside `docs/reference/` cannot be read.
- relative links to known reference docs are rewritten to `/docs/:slug`.

## HTTP verification

```bash
curl -fsS http://localhost:4000/docs
curl -fsS http://localhost:4000/docs/architecture
hurl --test --jobs 1 \
  --variable base_url=http://localhost:4000 \
  test/smoke/doc-viewer.hurl
```
