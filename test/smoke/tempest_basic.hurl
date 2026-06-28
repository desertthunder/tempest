# Baseline end-to-end PDS flow: health, metadata, records, sync, blobs.
#
# Verifies: createAccount, profile write, getLatestCommit, getRepo, getRecord,
# getBlocks, getRepoStatus, listRepos, uploadBlob, createRecord with blob
# reference, and listBlobs.
#
# A condensed integration of car-sync + blobs.
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

POST {{base_url}}/xrpc/com.atproto.repo.createRecord
Authorization: Bearer {{access_token}}
Content-Type: application/json
{
  "repo": "{{created_did}}",
  "collection": "app.bsky.actor.profile",
  "rkey": "self",
  "record": {
    "$type": "app.bsky.actor.profile",
    "displayName": "CAR Sync Smoke"
  }
}
HTTP 200
[Captures]
profile_cid: jsonpath "$.cid"
commit_cid: jsonpath "$.commit.cid"
commit_rev: jsonpath "$.commit.rev"
[Asserts]
jsonpath "$.commit.cid" exists
jsonpath "$.commit.rev" exists

GET {{base_url}}/xrpc/com.atproto.sync.getLatestCommit?did={{created_did}}
HTTP 200
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.cid" == "{{commit_cid}}"
jsonpath "$.rev" == "{{commit_rev}}"

GET {{base_url}}/xrpc/com.atproto.sync.getRepo?did={{created_did}}
HTTP 200
[Asserts]
header "content-type" contains "application/vnd.ipld.car"

GET {{base_url}}/xrpc/com.atproto.sync.getRecord?did={{created_did}}&collection=app.bsky.actor.profile&rkey=self
HTTP 200
[Asserts]
header "content-type" contains "application/vnd.ipld.car"

GET {{base_url}}/xrpc/com.atproto.sync.getBlocks?did={{created_did}}&cids%5B%5D={{profile_cid}}&cids%5B%5D={{commit_cid}}
HTTP 200
[Asserts]
header "content-type" contains "application/vnd.ipld.car"

GET {{base_url}}/xrpc/com.atproto.sync.getBlocks?did={{created_did}}&cids%5B%5D=not-a-cid
HTTP 400
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.error" == "InvalidRequest"

GET {{base_url}}/xrpc/com.atproto.sync.getRepoStatus?did={{created_did}}
HTTP 200
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.did" == "{{created_did}}"
jsonpath "$.active" == true
jsonpath "$.rev" == "{{commit_rev}}"

GET {{base_url}}/xrpc/com.atproto.sync.listRepos?limit=1000
HTTP 200
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.repos" exists

POST {{base_url}}/xrpc/com.atproto.repo.uploadBlob
Authorization: Bearer {{access_token}}
Content-Type: text/plain
`hello blob`
HTTP 200
[Captures]
blob_cid: jsonpath "$.blob.ref['$link']"
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.blob['$type']" == "blob"
jsonpath "$.blob.mimeType" == "text/plain"
jsonpath "$.blob.size" == 10

POST {{base_url}}/xrpc/com.atproto.repo.createRecord
Authorization: Bearer {{access_token}}
Content-Type: application/json
{
  "repo": "{{created_did}}",
  "collection": "app.tempest.blob",
  "rkey": "avatar",
  "validate": false,
  "record": {
    "$type": "app.tempest.blob",
    "image": {
      "$type": "blob",
      "ref": {"$link": "{{blob_cid}}"},
      "mimeType": "text/plain",
      "size": 10
    }
  }
}
HTTP 200

GET {{base_url}}/xrpc/com.atproto.sync.listBlobs?did={{created_did}}
HTTP 200
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.cids[0]" == "{{blob_cid}}"
jsonpath "$.cids[1]" not exists
