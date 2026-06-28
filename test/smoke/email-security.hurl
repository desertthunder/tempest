# Email security: password reset request and token consumption.
#
# Verifies: enumeration safety (unknown identifier returns 200), reset request
# for a real account, token consumption with new password, reuse rejection, and
# invalid token rejection.
#
# The raw token is operator-supplied because deployed Tempest does not expose
# issued tokens in any API response. Obtain it from the Swoosh mailbox preview
# (/dev/mailbox) in dev, from Resend's event log in production, or from an
# operator-injected test that captures the token before delivery.
#
# Required variables: base_url, account_email, account_password, reset_token
#
# Scope: local + deployed (token must be obtained out-of-band)

# ---------------------------------------------------------------------------
# Enumeration safety: requestPasswordReset returns 200 for unknown identifiers.
# ---------------------------------------------------------------------------

POST {{base_url}}/xrpc/com.atproto.server.requestPasswordReset
Content-Type: application/json
{
  "email": "does-not-exist-{{account_email}}"
}
HTTP 200

# ---------------------------------------------------------------------------
# Request a password reset for the target account. Returns 200 regardless of
# whether the account exists (enumeration-safe). The email with the token is
# delivered out-of-band; the operator supplies it as {{reset_token}}.
# ---------------------------------------------------------------------------

POST {{base_url}}/xrpc/com.atproto.server.requestPasswordReset
Content-Type: application/json
{
  "email": "{{account_email}}"
}
HTTP 200
[Asserts]
body not contains "{{reset_token}}"
body not contains "token_hash"

# ---------------------------------------------------------------------------
# Consume the operator-supplied reset token and set a new password.
# ---------------------------------------------------------------------------

POST {{base_url}}/xrpc/com.atproto.server.resetPassword
Content-Type: application/json
{
  "token": "{{reset_token}}",
  "password": "new {{account_password}}"
}
HTTP 200
[Asserts]
body == "{}"

# ---------------------------------------------------------------------------
# Token reuse is rejected.
# ---------------------------------------------------------------------------

POST {{base_url}}/xrpc/com.atproto.server.resetPassword
Content-Type: application/json
{
  "token": "{{reset_token}}",
  "password": "new {{account_password}}"
}
HTTP 400
[Asserts]
jsonpath "$.error" exists
jsonpath "$.message" exists

# ---------------------------------------------------------------------------
# Invalid token is rejected with a protocol-shaped error.
# ---------------------------------------------------------------------------

POST {{base_url}}/xrpc/com.atproto.server.resetPassword
Content-Type: application/json
{
  "token": "invalid-token-value",
  "password": "new {{account_password}}"
}
HTTP 400
[Asserts]
jsonpath "$.error" exists
jsonpath "$.message" exists
