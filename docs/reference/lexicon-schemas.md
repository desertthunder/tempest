---
title: Lexicon Schemas
updated: 2026-06-13
---

Lexicons describe AT Protocol schemas: XRPC methods, record shapes, object types,
refs, unions, and primitive constraints. Tempest uses Lexicons to validate record
writes without hardcoding application schemas in validator code.

## Concepts

A collection such as `app.bsky.actor.profile` is also a Lexicon NSID. A record's
`$type` should match its collection. If the PDS knows the schema, it can validate
fields and rkey rules before committing the record.

Unknown schemas are possible in an open protocol. Clients can ask for strict
validation; otherwise a PDS may accept unknown records while marking validation
status as unknown.

## Implementation

Tempest separates three concerns:

- schema engine: validates Lexicon documents and record values generically
- registry: answers whether a schema is known and trusted
- sources: bundled generated schemas, local configured schemas, and explicitly
  enabled external resolution

The registry source order is:

1. bundled generated schemas;
2. in-memory configured schemas, mostly for tests and controlled embedding;
3. operator-configured local files/directories;
4. operator-configured repository namespace sources;
5. external DNS/DID/PDS resolution, only when enabled and allowed.

Bundled schemas are generated from a pinned atproto Lexicon checkout and include
source metadata. The bundled set includes PDS-owned `com.atproto.*` schemas,
private compatibility schemas used by Tempest, and common Bluesky record schemas
needed for client compatibility such as `app.bsky.feed.post`.

Local repository sources let operators add larger schema sets without listing
each NSID. A repository source can point either at a git checkout root containing
`lexicons/` or directly at a lexicons directory, then select namespaces:

```elixir
config :tempest, Tempest.Lexicon.Registry,
  repositories: [
    [path: "/srv/lexicons/standard", namespaces: ["site.standard"]],
    [path: "/srv/checkouts/atproto", namespaces: ["app.bsky.feed"]]
  ]
```

The generator has the same namespace concept for bundled data:

```bash
mix tempest.lexicon.generate \
  --source ../atproto/lexicons \
  --commit <commit> \
  --namespace app.bsky.feed,com.atproto.repo
```

Documents selected by namespace still pull in referenced local dependencies
when the dependency document is present in the source tree.

## External resolution

Tempest can resolve missing Lexicons through the AT Protocol publication model.
This path is disabled by default and enabled with:

```bash
TEMPEST_LEXICON_EXTERNAL_RESOLVER=true
```

When enabled, `site.standard.*` is allowed by default. For an NSID such as
`site.standard.document`, Tempest:

1. derives the authority domain from the NSID by removing the final segment and
   reversing the remaining authority, so `site.standard.document` becomes
   `standard.site`;
2. reads TXT records at `_lexicon.standard.site`;
3. looks for a value like `did=did:plc:...`;
4. resolves that DID document;
5. finds the `AtprotoPersonalDataServer` service;
6. fetches:

   ```text
   /xrpc/com.atproto.repo.getRecord
     ?repo=<did>
     &collection=com.atproto.lexicon.schema
     &rkey=<nsid>
   ```

7. validates that the returned Lexicon document has the requested `id`.

External resolution is intentionally constrained:

- bundled, in-memory, local file, and local repository sources always win;
- external documents cannot override local trusted sources;
- only the built-in `site.standard` namespace is resolved by default;
- redirects are rejected;
- response bodies are size-bounded;
- receive/connect timeouts are short;
- SSRF checks reject private service endpoints;
- successful and failed lookups are cached;
- stale positive cache entries can be used when a refresh fails.

The resolver can still be extended in application config or tests by passing
additional allowed namespaces, but the deployed default is intentionally small.

## Known-record fallback

Tempest also has a DNS over HTTP fallback for selected known record namespaces. If a
write passes generic record checks but schema lookup fails, records under
`site.standard.*` are treated as known and return `validationStatus: "valid"`.

This fallback only runs after:

- the record has a `$type`;
- `$type` matches the collection;
- the collection is a valid NSID;
- the rkey has valid record-key syntax;
- normal repo authorization and storage safety checks pass.

It does not validate field-level schema constraints. It exists to keep selected
ecosystem records writable when DNS resolution is temporarily unavailable, while
keeping arbitrary unknown records on the normal `unknown` or strict-reject path.

Operators can add individual fallback IDs with:

```bash
TEMPEST_LEXICON_KNOWN_RECORDS=example.app.record,example.app.other
```

## Record validation behavior

For record writes:

- known schema + validation enabled: validate and return `valid`
- known-record fallback + validation enabled: return `valid` after generic
  checks
- unknown schema + `validate: true`: reject with `InvalidRequest`
- unknown schema + validation unset: accept and return `unknown`
- `validate: false`: skip schema validation after generic safety checks

Generic safety checks still apply: `$type`, collection NSID, rkey syntax, record
size, CBOR limits, and repo write authorization.

## Operator workflow

Regenerate bundled schemas from a pinned source when updating the known atproto
Lexicon set. Local schemas should fail startup/generation if they contain invalid
or duplicate IDs.

Use repository namespace sources for schemas that should remain local and
deterministic. Use external resolution for selected ecosystem namespaces where
runtime discovery is useful. If an external namespace becomes operationally
critical, vendor it into a local repository source or the generated bundle.

## Verification

```bash
mix tempest.lexicon.generate --source ../atproto/lexicons --commit <commit>
mix tempest.lexicon.generate --source ../atproto/lexicons --commit <commit> --namespace app.bsky.feed
mix test test/tempest/lexicon
hurl --test --jobs 1 --variable base_url=http://localhost:4000 test/smoke/lexicon-schemas.hurl
```

To verify live DNS resolution for the built-in external namespace:

```bash
mix run -e 'ids = ~w(site.standard.document site.standard.graph.recommend site.standard.graph.subscription site.standard.publication); Enum.each(ids, fn id -> IO.puts("== #{id}"); case Tempest.Lexicon.ExternalResolver.Network.resolve(id) do {:ok, doc} -> IO.puts(Jason.encode!(doc, pretty: true)); {:error, reason} -> IO.inspect(reason, label: "error") end end)'
```
