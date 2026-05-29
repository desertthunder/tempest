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

- Local PDS-owned endpoints remain locally implemented.
- Service surface such as `app.bsky.feed.*` and `chat.bsky.*` may proxy to a configured
  AppView via `Tempest.Xrpc.Proxy`.
- `app.bsky.actor.getPreferences` and `app.bsky.actor.putPreferences` are intentionally
  local because they carry private account migration state.
- If no AppView upstream is configured, proxyable unknown service methods return
  protocol-shaped `UnknownMethod` instead of silently failing.

## Smoke commands

```bash
hurl --test --jobs 1 --variable base_url=http://localhost:4000 test/smoke/tempest_basic.hurl
hurl --test --jobs 1 --variable base_url=http://localhost:4000 test/smoke/tempest_compat.hurl
```

External relay/AppView checks should be documented with the upstream host, atproto
commit/SDK version, date, and observed failures before changing compatibility status.
