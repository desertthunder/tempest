POST {{base_url}}/xrpc/com.atproto.server.createAccount
Content-Type: application/json
{
  "handle": "records-{{newUuid}}.test",
  "email": "records-{{newUuid}}@example.com",
  "password": "correct horse battery staple"
}
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
  "collection": "app.bsky.actor.profile",
  "rkey": "self",
  "record": {
    "$type": "app.bsky.actor.profile",
    "displayName": "Smoke Profile"
  }
}
HTTP 200
[Captures]
created_uri: jsonpath "$.uri"
created_cid: jsonpath "$.cid"
created_commit_cid: jsonpath "$.commit.cid"
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.uri" == "at://{{created_did}}/app.bsky.actor.profile/self"
jsonpath "$.cid" exists
jsonpath "$.commit.cid" exists
jsonpath "$.commit.rev" exists
jsonpath "$.validationStatus" exists

GET {{base_url}}/xrpc/com.atproto.repo.getRecord?repo={{created_did}}&collection=app.bsky.actor.profile&rkey=self
HTTP 200
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.uri" == "{{created_uri}}"
jsonpath "$.cid" == "{{created_cid}}"
jsonpath "$.value.displayName" == "Smoke Profile"

GET {{base_url}}/xrpc/com.atproto.repo.listRecords?repo={{created_did}}&collection=app.bsky.actor.profile
HTTP 200
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.records[0].uri" == "{{created_uri}}"
jsonpath "$.records[0].cid" == "{{created_cid}}"
jsonpath "$.records[0].value.displayName" == "Smoke Profile"
jsonpath "$.records[1]" not exists

GET {{base_url}}/xrpc/com.atproto.repo.describeRepo?repo={{created_did}}
HTTP 200
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.did" == "{{created_did}}"
jsonpath "$.didDoc.id" == "{{created_did}}"
jsonpath "$.collections[0]" == "app.bsky.actor.profile"
jsonpath "$.handleIsCorrect" == true

POST {{base_url}}/xrpc/com.atproto.repo.createRecord
Authorization: Bearer {{access_token}}
Content-Type: application/json
{
  "repo": "{{created_did}}",
  "collection": "app.bsky.actor.profile",
  "rkey": "self",
  "record": {
    "$type": "app.bsky.actor.profile",
    "displayName": "Duplicate Profile"
  }
}
HTTP 409
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.error" == "InvalidRequest"

POST {{base_url}}/xrpc/com.atproto.repo.putRecord
Authorization: Bearer {{access_token}}
Content-Type: application/json
{
  "repo": "{{created_did}}",
  "collection": "app.bsky.actor.profile",
  "rkey": "self",
  "swapRecord": "{{created_commit_cid}}",
  "record": {
    "$type": "app.bsky.actor.profile",
    "displayName": "Rejected Profile"
  }
}
HTTP 409
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.error" == "InvalidSwap"

POST {{base_url}}/xrpc/com.atproto.repo.putRecord
Authorization: Bearer {{access_token}}
Content-Type: application/json
{
  "repo": "{{created_did}}",
  "collection": "app.bsky.actor.profile",
  "rkey": "self",
  "swapRecord": "{{created_cid}}",
  "swapCommit": "{{created_commit_cid}}",
  "record": {
    "$type": "app.bsky.actor.profile",
    "displayName": "Updated Smoke Profile"
  }
}
HTTP 200
[Captures]
updated_cid: jsonpath "$.cid"
updated_commit_cid: jsonpath "$.commit.cid"
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.uri" == "{{created_uri}}"
jsonpath "$.cid" exists
jsonpath "$.commit.cid" exists

GET {{base_url}}/xrpc/com.atproto.repo.getRecord?repo={{created_did}}&collection=app.bsky.actor.profile&rkey=self
HTTP 200
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.cid" == "{{updated_cid}}"
jsonpath "$.value.displayName" == "Updated Smoke Profile"

POST {{base_url}}/xrpc/com.atproto.repo.deleteRecord
Authorization: Bearer {{access_token}}
Content-Type: application/json
{
  "repo": "{{created_did}}",
  "collection": "app.bsky.actor.profile",
  "rkey": "self",
  "swapRecord": "{{updated_cid}}",
  "swapCommit": "{{updated_commit_cid}}"
}
HTTP 200
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.commit.cid" exists

GET {{base_url}}/xrpc/com.atproto.repo.getRecord?repo={{created_did}}&collection=app.bsky.actor.profile&rkey=self
HTTP 400
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.error" == "RecordNotFound"

GET {{base_url}}/xrpc/com.atproto.repo.listRecords?repo={{created_did}}&collection=app.bsky.actor.profile
HTTP 200
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.records[0]" not exists
