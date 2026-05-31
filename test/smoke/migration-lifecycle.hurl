POST {{base_url}}/xrpc/com.atproto.server.createAccount
Content-Type: application/json
{
  "handle": "migration-{{newUuid}}.test",
  "email": "migration-{{newUuid}}@example.com",
  "password": "correct horse battery staple"
}
HTTP 200
[Captures]
did: jsonpath "$.did"
access_token: jsonpath "$.accessJwt"
[Asserts]
jsonpath "$.active" == true

GET {{base_url}}/xrpc/com.atproto.server.checkAccountStatus
Authorization: Bearer {{access_token}}
HTTP 200
[Asserts]
jsonpath "$.did" == "{{did}}"
jsonpath "$.active" == true
jsonpath "$.repoCount" == 1
jsonpath "$.recordCount" == 0
jsonpath "$.missingBlobCount" == 0
jsonpath "$.migrationReady" == true

GET {{base_url}}/xrpc/com.atproto.server.getServiceAuth?aud=did:web:tempest.example.com&lxm=com.atproto.repo.importRepo
Authorization: Bearer {{access_token}}
HTTP 200
[Asserts]
jsonpath "$.token" exists

POST {{base_url}}/xrpc/com.atproto.repo.createRecord
Authorization: Bearer {{access_token}}
Content-Type: application/json
{
  "repo": "{{did}}",
  "collection": "app.bsky.actor.profile",
  "rkey": "self",
  "record": {
    "$type": "app.bsky.actor.profile",
    "displayName": "Migration Smoke"
  }
}
HTTP 200
[Captures]
commit_rev: jsonpath "$.commit.rev"
[Asserts]
jsonpath "$.commit.cid" exists

GET {{base_url}}/xrpc/com.atproto.sync.getRepo?did={{did}}
HTTP 200
[Asserts]
header "content-type" contains "application/vnd.ipld.car"

POST {{base_url}}/xrpc/com.atproto.repo.importRepo
Authorization: Bearer {{access_token}}
Content-Type: application/vnd.ipld.car
`not a car`
HTTP 400
[Asserts]
jsonpath "$.error" == "InvalidRequest"

GET {{base_url}}/xrpc/com.atproto.server.checkAccountStatus
Authorization: Bearer {{access_token}}
HTTP 200
[Asserts]
jsonpath "$.recordCount" == 1

GET {{base_url}}/xrpc/com.atproto.repo.listMissingBlobs
Authorization: Bearer {{access_token}}
HTTP 200
[Asserts]
jsonpath "$.blobs[0]" not exists

POST {{base_url}}/xrpc/com.atproto.server.deactivateAccount
Authorization: Bearer {{access_token}}
Content-Type: application/json
{}
HTTP 200

GET {{base_url}}/xrpc/com.atproto.sync.getRepo?did={{did}}
HTTP 400
[Asserts]
jsonpath "$.error" == "RepoDeactivated"

POST {{base_url}}/xrpc/com.atproto.server.activateAccount
Authorization: Bearer {{access_token}}
Content-Type: application/json
{}
HTTP 200

GET {{base_url}}/xrpc/com.atproto.sync.getLatestCommit?did={{did}}
HTTP 200
[Asserts]
jsonpath "$.rev" == "{{commit_rev}}"

POST {{base_url}}/xrpc/com.atproto.server.requestAccountDelete
Authorization: Bearer {{access_token}}
Content-Type: application/json
{}
HTTP 200

POST {{base_url}}/xrpc/com.atproto.server.deleteAccount
Authorization: Bearer {{access_token}}
Content-Type: application/json
{}
HTTP 200

GET {{base_url}}/xrpc/com.atproto.sync.getRepoStatus?did={{did}}
HTTP 200
[Asserts]
jsonpath "$.active" == false
jsonpath "$.status" == "deleted"
