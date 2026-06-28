# XRPC dispatch and protocol-shaped errors.
#
# Verifies: health endpoint, describeServer metadata, unknown method rejection,
# and invalid POST handling.
#
# Required variables: base_url
#
# Scope: local + deployed

GET {{base_url}}/xrpc/_health
HTTP 200
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.status" == "ok"

GET {{base_url}}/xrpc/com.atproto.server.describeServer
HTTP 200
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.did" exists
jsonpath "$.availableUserDomains" exists
jsonpath "$.inviteCodeRequired" == false
jsonpath "$.phoneVerificationRequired" == false
jsonpath "$.links" exists
jsonpath "$.contact" exists

POST {{base_url}}/xrpc/com.atproto.server.describeServer
HTTP 400
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.error" == "InvalidRequest"

GET {{base_url}}/xrpc/com.atproto.unknown.method
HTTP 404
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.error" == "UnknownMethod"
