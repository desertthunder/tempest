---
title: External Relay and AppView Verification Notes
updated: 2026-05-29
---

## Relay

- `com.atproto.sync.requestCrawl` accepts only the configured local hostname and
  rate-limits repeated requests.
- Configure relay targets with `config :tempest, Tempest.Sync, relays: ["https://relay.example"]` for staging.
- Verify manually against a real relay by creating an account, writing a record, calling
  `requestCrawl`, and confirming the relay can fetch `getRepo`, `getLatestCommit`, and
  `subscribeRepos` frames.
- Keep production relay checks opt-in; they require network access and external service
  credentials/availability.

## AppView

- Tempest is a PDS, not an AppView. Local PDS-owned endpoints remain locally
  implemented.
- `app.bsky.actor.getPreferences` and `app.bsky.actor.putPreferences` are
  intentionally local because they carry private account migration state.
- Unknown service methods whose NSID starts with `app.bsky.` or `chat.bsky.` are
  proxy-eligible only when `Tempest.Xrpc.Proxy` is configured with an
  `upstream_base_url`.
- Proxy requests preserve the original HTTP verb, query parameters or JSON body,
  and the `authorization`, `accept`, and `content-type` headers. Responses
  preserve the upstream status, content type, and body.
- If no AppView upstream is configured, proxyable unknown service methods return
  protocol-shaped `UnknownMethod` instead of silently failing.
- Unknown `com.atproto.*` methods are never proxied.

## Smoke commands

```bash
hurl --test --jobs 1 --variable base_url=http://localhost:4000 test/smoke/tempest_basic.hurl
hurl --test --jobs 1 --variable base_url=http://localhost:4000 test/smoke/tempest_compat.hurl
```

External relay/AppView checks should be documented with the upstream host,
atproto commit or protocol version, date, and observed failures before changing
compatibility status.
