# Identity correctness: .well-known/atproto-did, resolveHandle, and getSession.
#
# Verifies that the DID document, handle resolution, and session all agree on
# the account's DID and handle after creation.
#
# Required variables: base_url, handle, access, did
#
# Note: account must be pre-created and variables captured before running.
#
# Scope: local + deployed

POST {{base_url}}/xrpc/com.atproto.server.createAccount
HTTP 200
[Captures]
did: jsonpath "$.did"
handle: jsonpath "$.handle"
access: jsonpath "$.accessJwt"
[Asserts]
jsonpath "$.did" startsWith "did:plc:"

GET {{base_url}}/.well-known/atproto-did
Host: {{handle}}
HTTP 200
[Asserts]
body == "{{did}}"

GET {{base_url}}/xrpc/com.atproto.identity.resolveHandle?handle={{handle}}
HTTP 200
[Asserts]
jsonpath "$.did" == "{{did}}"

GET {{base_url}}/xrpc/com.atproto.server.getSession
Authorization: Bearer {{access}}
HTTP 200
[Asserts]
jsonpath "$.did" == "{{did}}"
jsonpath "$.handle" == "{{handle}}"
