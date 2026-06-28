# Blob lifecycle: upload, reference, list, serve, and delete.
#
# Verifies: uploadBlob, createRecord with blob reference, listBlobs, getBlob,
# deleteRecord cleanup, and 404 after deletion.
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

GET {{base_url}}/xrpc/com.atproto.sync.listBlobs?did={{created_did}}
HTTP 200
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.cids[0]" not exists

GET {{base_url}}/xrpc/com.atproto.sync.getBlob?did={{created_did}}&cid={{blob_cid}}
HTTP 400
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.error" == "BlobNotFound"

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
[Captures]
record_cid: jsonpath "$.cid"
record_commit_cid: jsonpath "$.commit.cid"
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.uri" == "at://{{created_did}}/app.tempest.blob/avatar"

GET {{base_url}}/xrpc/com.atproto.sync.listBlobs?did={{created_did}}
HTTP 200
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.cids[0]" == "{{blob_cid}}"
jsonpath "$.cids[1]" not exists

GET {{base_url}}/xrpc/com.atproto.sync.getBlob?did={{created_did}}&cid={{blob_cid}}
HTTP 200
[Asserts]
header "content-type" == "text/plain"
header "content-length" == "10"
header "x-content-type-options" == "nosniff"
header "content-security-policy" == "default-src 'none'; sandbox"
body == "hello blob"

POST {{base_url}}/xrpc/com.atproto.repo.deleteRecord
Authorization: Bearer {{access_token}}
Content-Type: application/json
{
  "repo": "{{created_did}}",
  "collection": "app.tempest.blob",
  "rkey": "avatar",
  "swapRecord": "{{record_cid}}",
  "swapCommit": "{{record_commit_cid}}"
}
HTTP 200
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.commit.cid" exists

GET {{base_url}}/xrpc/com.atproto.sync.getBlob?did={{created_did}}&cid={{blob_cid}}
HTTP 400
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.error" == "BlobNotFound"
