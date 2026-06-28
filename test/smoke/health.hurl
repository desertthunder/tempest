# Health check: service status and storage writability.
#
# Verifies: /xrpc/_health returns 200 with status, version, and storage paths.
#
# Required variables: base_url
#
# Scope: local + deployed

GET {{base_url}}/xrpc/_health
HTTP 200
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.version" exists
jsonpath "$.status" == "ok"
jsonpath "$.storage.dataDir" exists
jsonpath "$.storage.accountDb" exists
jsonpath "$.storage.sequencerDb" exists
jsonpath "$.storage.writable" == true
