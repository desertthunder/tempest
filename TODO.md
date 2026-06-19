# Parking Lot (TODO)

- Add OAuth token introspection:
  - expose `/oauth/introspect`
  - return inactive for missing, revoked, rotated, expired, or malformed tokens
  - return active token metadata for valid OAuth access or refresh tokens
  - require client authentication and verify the requester is allowed to inspect
    the token
