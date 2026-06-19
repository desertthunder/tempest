# Parking Lot (TODO)

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
