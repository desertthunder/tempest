POST {{base_url}}/xrpc/com.atproto.server.createAccount
Content-Type: application/json
{
  "handle": "compat-{{newUuid}}.test",
  "email": "compat-{{newUuid}}@example.com",
  "password": "correct horse battery staple"
}
HTTP 200
[Captures]
did: jsonpath "$.did"
access: jsonpath "$.accessJwt"
[Asserts]
jsonpath "$.did" startsWith "did:plc:"

GET {{base_url}}/xrpc/app.bsky.actor.getPreferences
Authorization: Bearer {{access}}
HTTP 200
[Asserts]
jsonpath "$.preferences" isCollection

POST {{base_url}}/xrpc/app.bsky.actor.putPreferences
Authorization: Bearer {{access}}
Content-Type: application/json
{
  "preferences": [
    {"$type": "app.bsky.actor.defs#adultContentPref", "enabled": true}
  ]
}
HTTP 200

POST {{base_url}}/xrpc/com.atproto.repo.applyWrites
Authorization: Bearer {{access}}
Content-Type: application/json
{
  "repo": "{{did}}",
  "validate": false,
  "writes": [
    {
      "$type": "com.atproto.repo.applyWrites#create",
      "collection": "app.tempest.note",
      "rkey": "one",
      "value": {"$type": "app.tempest.note", "text": "compat one"}
    },
    {
      "$type": "com.atproto.repo.applyWrites#create",
      "collection": "app.tempest.note",
      "rkey": "two",
      "value": {"$type": "app.tempest.note", "text": "compat two"}
    }
  ]
}
HTTP 200
[Captures]
commit: jsonpath "$.commit.cid"
record_cid: jsonpath "$.results[0].cid"
[Asserts]
jsonpath "$.results[0]['$type']" == "com.atproto.repo.applyWrites#createResult"

GET {{base_url}}/xrpc/com.atproto.sync.getBlocks?did={{did}}&cids%5B%5D={{record_cid}}&cids%5B%5D={{commit}}
HTTP 200
[Asserts]
header "content-type" contains "application/vnd.ipld.car"

GET {{base_url}}/xrpc/app.bsky.feed.getTimeline?limit=1
HTTP 404
[Asserts]
jsonpath "$.error" == "UnknownMethod"
