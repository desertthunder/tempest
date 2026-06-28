# Firehose: repo commit event observation over WebSocket.
#
# Hurl 8.0.0 in this environment does not provide a WebSocket client, so the
# binary subscribe/write/receive stream is covered by ExUnit.
#
# This smoke test verifies the public setup path, durable commit creation,
# and the subscribeRepos HTTP upgrade boundary.
#
# Crawler fan-out is covered by crawlers.hurl.
#
# Required variables: base_url, newUuid (hurl built-in)
#
# Scope: local + deployed

POST {{base_url}}/xrpc/com.atproto.server.createAccount
HTTP 200
[Captures]
created_did: jsonpath "$.did"
access_token: jsonpath "$.accessJwt"
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.did" startsWith "did:plc:"
jsonpath "$.accessJwt" exists

POST {{base_url}}/xrpc/com.atproto.repo.createRecord
Authorization: Bearer {{access_token}}
Content-Type: application/json
{
  "repo": "{{created_did}}",
  "collection": "app.tempest.note",
  "rkey": "firehose",
  "validate": false,
  "record": {
    "$type": "app.tempest.note",
    "text": "smoke event"
  }
}
HTTP 200
[Captures]
record_cid: jsonpath "$.cid"
commit_cid: jsonpath "$.commit.cid"
commit_rev: jsonpath "$.commit.rev"
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.uri" == "at://{{created_did}}/app.tempest.note/firehose"
jsonpath "$.cid" exists
jsonpath "$.commit.cid" exists
jsonpath "$.commit.rev" exists

GET {{base_url}}/xrpc/com.atproto.sync.getLatestCommit?did={{created_did}}
HTTP 200
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.cid" == "{{commit_cid}}"
jsonpath "$.rev" == "{{commit_rev}}"

GET {{base_url}}/xrpc/com.atproto.sync.getBlocks?did={{created_did}}&cids%5B%5D={{record_cid}}&cids%5B%5D={{commit_cid}}
HTTP 200
[Asserts]
header "content-type" contains "application/vnd.ipld.car"

GET {{base_url}}/xrpc/com.atproto.sync.subscribeRepos?cursor=0
HTTP 426
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.error" == "UpgradeRequired"
