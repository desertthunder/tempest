# CHANGELOG

## v0.1.0

### 2026-05-07

- Home page with weird "unix appliance" style

- DID and handle validators, signing key generation, DID document builder, `/.well-known/atproto-did` route
- DNS TXT and HTTPS well-known handle resolvers, SSRF protection, `resolveHandle`, and `updateHandle` with bidirectional verification.
- SQLite account storage with password hashing, access and refresh token signing, session XRPC endpoints (`createSession`, `refreshSession`, `deleteSession`, `getSession`), and a bearer auth plug.

- XRPC router pipeline, method registry, protocol-shaped JSON error renderer, verb mismatch handling, and `com.atproto.server.describeServer`.

- `Tempest.Config` module with hostname/data-dir validation, `/xrpc/_health` JSON endpoint, and a `test/smoke` scaffold with Hurl verification commands.
