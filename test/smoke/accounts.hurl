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
created_access_token: jsonpath "$.accessJwt"
created_refresh_token: jsonpath "$.refreshJwt"
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.did" exists
jsonpath "$.handle" == "{{account_handle}}"
jsonpath "$.email" == "{{account_email}}"
jsonpath "$.accessJwt" exists
jsonpath "$.refreshJwt" exists

POST {{base_url}}/xrpc/com.atproto.server.createSession
Content-Type: application/json
{
  "identifier": "{{account_handle}}",
  "password": "{{account_password}}"
}
HTTP 200
[Captures]
access_token: jsonpath "$.accessJwt"
refresh_token: jsonpath "$.refreshJwt"
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.did" == "{{created_did}}"
jsonpath "$.handle" == "{{account_handle}}"
jsonpath "$.accessJwt" exists
jsonpath "$.refreshJwt" exists

GET {{base_url}}/xrpc/com.atproto.server.getSession
Authorization: Bearer {{access_token}}
HTTP 200
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.did" == "{{created_did}}"
jsonpath "$.handle" == "{{account_handle}}"
jsonpath "$.password_hash" not exists
jsonpath "$.refreshJwt" not exists

GET {{base_url}}/xrpc/com.atproto.server.getSession
HTTP 401
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.error" == "AuthenticationRequired"

POST {{base_url}}/xrpc/com.atproto.server.refreshSession
Authorization: Bearer {{refresh_token}}
HTTP 200
[Captures]
rotated_refresh_token: jsonpath "$.refreshJwt"
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.did" == "{{created_did}}"
jsonpath "$.handle" == "{{account_handle}}"
jsonpath "$.accessJwt" exists
jsonpath "$.refreshJwt" exists

POST {{base_url}}/xrpc/com.atproto.server.deleteSession
Authorization: Bearer {{rotated_refresh_token}}
HTTP 200
[Asserts]
header "content-type" contains "application/json"

POST {{base_url}}/xrpc/com.atproto.server.refreshSession
Authorization: Bearer {{rotated_refresh_token}}
HTTP 401
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.error" == "InvalidToken"
