# Deployed crawler smoke coverage.
#
# Requires a publicly reachable PDS hostname. Real relays reject localhost and
# private names, so do not run this file as part of the local smoke suite unless
# the server was started with TEMPEST_CRAWLERS pointing at a local fake relay.

POST {{base_url}}/xrpc/com.atproto.sync.requestCrawl
Content-Type: application/json
{
  "hostname": "{{crawler_hostname}}"
}
HTTP 200
[Asserts]
header "content-type" contains "application/json"
jsonpath "$" exists

POST {{base_url}}/xrpc/com.atproto.sync.requestCrawl
Content-Type: application/json
{
  "hostname": "not-{{crawler_hostname}}"
}
HTTP 400
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.error" == "InvalidRequest"
