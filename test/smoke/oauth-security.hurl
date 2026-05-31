GET {{base_url}}/.well-known/oauth-protected-resource
HTTP 200
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.resource" exists
jsonpath "$.authorization_servers[0]" exists

GET {{base_url}}/.well-known/oauth-authorization-server
HTTP 200
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.issuer" exists
jsonpath "$.pushed_authorization_request_endpoint" exists
jsonpath "$.token_endpoint" exists

GET {{base_url}}/oauth/jwks
HTTP 200
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.keys" isCollection

POST {{base_url}}/oauth/par
[FormParams]
client_id: did:web:client.example.com
redirect_uri: https://client.example.com/cb
scope: atproto
response_type: code
code_challenge: abc
code_challenge_method: S256
HTTP 401
[Captures]
dpop_nonce: header "dpop-nonce"
[Asserts]
jsonpath "$.error" == "invalid_dpop_proof"

POST {{base_url}}/oauth/token
[FormParams]
grant_type: unsupported
client_id: did:web:client.example.com
HTTP 400
[Asserts]
jsonpath "$.error" == "unsupported_grant_type"

POST {{base_url}}/oauth/revoke
[FormParams]
token: not-a-real-token
client_id: did:web:client.example.com
HTTP 200
