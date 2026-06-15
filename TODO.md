# Parking Lot (TODO)

- Add OAuth `private_key_jwt` client authentication:
  - accept client metadata with `token_endpoint_auth_method: "private_key_jwt"`
  - fetch and validate inline `jwks` or remote `jwks_uri`
  - verify client assertions for `iss`, `sub`, `aud`, `exp`/`iat`, `jti`, `kid`,
    algorithm, and signature
  - reject assertion replay
  - cover PAR, token exchange, refresh, and failure cases

- Add OAuth loopback development client metadata:
  - support the `http://localhost` client ID profile used by AT Protocol OAuth
    development clients
  - synthesize metadata from `redirect_uri` and `scope` query parameters
  - restrict loopback redirect URIs to HTTP loopback hosts
  - keep non-loopback clients on HTTPS metadata documents

- Add OAuth private-use redirect scheme support for native clients:
  - accept reverse-domain private-use schemes only for native clients
  - reject credentials, hosts, ports, fragments, and local/reserved scheme roots
  - keep HTTP redirect URI support limited to loopback clients

- Add OAuth token introspection:
  - expose `/oauth/introspect`
  - return inactive for missing, revoked, rotated, expired, or malformed tokens
  - return active token metadata for valid OAuth access or refresh tokens
  - require client authentication and verify the requester is allowed to inspect
    the token
