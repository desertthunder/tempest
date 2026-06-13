# Deployed HTTPS smoke coverage.
#
# Run against a publicly reachable HTTPS deployment with the final hostname:
#
#   hurl --test --jobs 1 \
#     --variable base_url=https://tempest.example.com \
#     --variable admin_token="$ADMIN_TOKEN" \
#     test/smoke/deployment.hurl
#
# This file is intentionally non-destructive. Account writes, blob writes, relay
# crawl, and real-client checks are covered by the broader deployment runbook.

GET {{base_url}}/xrpc/_health
HTTP 200
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.status" == "ok"
jsonpath "$.version" exists
jsonpath "$.storage.dataDir" exists
jsonpath "$.storage.writable" == true

GET {{base_url}}/xrpc/com.atproto.server.describeServer
HTTP 200
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.did" exists
jsonpath "$.availableUserDomains" exists
jsonpath "$.inviteCodeRequired" == false
jsonpath "$.links.privacyPolicy" exists
jsonpath "$.links.termsOfService" exists

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

GET {{base_url}}/xrpc/_admin/status
HTTP 401
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.error" == "AuthenticationRequired"

GET {{base_url}}/xrpc/_admin/status
Authorization: Bearer not-the-admin-token
HTTP 401
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.error" == "InvalidToken"

GET {{base_url}}/xrpc/_admin/status
Authorization: Bearer {{admin_token}}
HTTP 200
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.status" == "ok"
jsonpath "$.database.accountDb.exists" == true
jsonpath "$.database.sequencerDb.exists" == true
jsonpath "$.sequencer.currentSeq" exists
jsonpath "$.blobStore" exists

GET {{base_url}}/admin/storage
Authorization: Bearer {{admin_token}}
HTTP 200
[Asserts]
header "content-type" contains "text/html"
body contains "Storage Status"

GET {{base_url}}/xrpc/com.atproto.unknown.method
HTTP 404
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.error" == "UnknownMethod"
