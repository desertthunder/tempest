POST {{base_url}}/xrpc/com.atproto.server.createAccount
Content-Type: application/json
{
  "handle": "identity-correct-{{newUuid}}.test",
  "email": "identity-correct-{{newUuid}}@example.com",
  "password": "correct horse battery staple"
}
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
