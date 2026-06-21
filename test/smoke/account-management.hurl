POST {{base_url}}/xrpc/com.atproto.server.createAccount
Content-Type: application/json
{
  "handle": "account-panel-{{suffix}}.test",
  "email": "account-panel-{{suffix}}@example.com",
  "password": "correct horse battery staple"
}
HTTP 200
[Captures]
account_did: jsonpath "$.did"
account_access_token: jsonpath "$.accessJwt"

GET {{base_url}}/account
HTTP 302
[Asserts]
header "location" contains "/account/login"

GET {{base_url}}/account/login?return_to=/account
HTTP 200
[Captures]
account_csrf: xpath "string(//input[@name='_csrf_token']/@value)"
[Asserts]
body contains "account-login-form"
body contains "Enter Tempest Password"
body not contains "{{account_access_token}}"

POST {{base_url}}/account/login
[FormParams]
_csrf_token: {{account_csrf}}
return_to: /account
account[identifier]: account-panel-{{suffix}}.test
account[password]: correct horse battery staple
HTTP 302
[Asserts]
header "location" == "/account"

GET {{base_url}}/account
HTTP 200
[Asserts]
body contains "account-dashboard"
body contains "{{account_did}}"
body not contains "{{account_access_token}}"

GET {{base_url}}/account/repo
HTTP 200
[Asserts]
body contains "repo-browser"

GET {{base_url}}/account/blobs
HTTP 200
[Asserts]
body contains "blob-browser"

GET {{base_url}}/account/access
HTTP 200
[Asserts]
body contains "account-access"
body not contains "{{account_access_token}}"

GET {{base_url}}/account/security
HTTP 200
[Asserts]
body contains "account-security"

GET {{base_url}}/account/logout
HTTP 302
[Asserts]
header "location" == "/"

GET {{base_url}}/account
HTTP 302
[Asserts]
header "location" contains "/account/login"
