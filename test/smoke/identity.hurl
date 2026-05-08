POST {{base_url}}/xrpc/com.atproto.server.createAccount
Content-Type: application/json
{
  "handle": "{{account_handle}}",
  "email": "{{account_email}}",
  "password": "{{account_password}}"
}
HTTP 200
[Captures]
created_did: jsonpath "$.did"
access_token: jsonpath "$.accessJwt"
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.did" startsWith "did:plc:"
jsonpath "$.handle" == "{{account_handle}}"

GET {{base_url}}/.well-known/atproto-did
Host: {{account_handle}}
HTTP 200
[Asserts]
header "content-type" contains "text/plain"
body == "{{created_did}}"

GET {{base_url}}/xrpc/com.atproto.identity.resolveHandle?handle={{account_handle}}
HTTP 200
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.did" == "{{created_did}}"

GET {{base_url}}/xrpc/com.atproto.identity.resolveHandle?handle=not-a-handle
HTTP 400
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.error" == "InvalidRequest"

POST {{base_url}}/xrpc/com.atproto.identity.updateHandle
Authorization: Bearer {{access_token}}
Content-Type: application/json
{
  "handle": "{{account_handle}}"
}
HTTP 200
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.did" == "{{created_did}}"
jsonpath "$.handle" == "{{account_handle}}"
