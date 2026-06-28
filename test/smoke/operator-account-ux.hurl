# Operator account UI: browser control panel pages behind bearer-token auth.
#
# Verifies: account dashboard, repo browser, blob browser, sequencer viewer, and
# firehose viewer pages render with expected content when accessed with an
# XRPC bearer token. Also verifies unauthenticated access redirects to login.
#
# Required variables: base_url, suffix
#
# Scope: local + deployed

POST {{base_url}}/xrpc/com.atproto.server.createAccount
HTTP 200
[Captures]
did: jsonpath "$.did"
access_token: jsonpath "$.accessJwt"

POST {{base_url}}/xrpc/com.atproto.repo.createRecord
Authorization: Bearer {{access_token}}
Content-Type: application/json
{
  "repo": "{{did}}",
  "collection": "app.bsky.actor.profile",
  "rkey": "self",
  "record": {
    "$type": "app.bsky.actor.profile",
    "displayName": "Operator UX"
  }
}
HTTP 200

GET {{base_url}}/account
HTTP 302
[Asserts]
header "location" contains "/account/login"

GET {{base_url}}/account
Authorization: Bearer {{access_token}}
HTTP 200
[Asserts]
header "content-type" contains "text/html"
body contains "Account Dashboard"
body contains "{{did}}"

GET {{base_url}}/account/repo
Authorization: Bearer {{access_token}}
HTTP 200
[Asserts]
body contains "Repo Browser"
body contains "app.bsky.actor.profile/self"
body contains "Operator UX"

POST {{base_url}}/xrpc/com.atproto.repo.uploadBlob
Authorization: Bearer {{access_token}}
Content-Type: text/plain
`operator blob`
HTTP 200

GET {{base_url}}/account/blobs
Authorization: Bearer {{access_token}}
HTTP 200
[Asserts]
body contains "Blob Browser"
body contains "temp"
body contains "Content-Length"

GET {{base_url}}/account/sequencer?did={{did}}&type=%23commit
Authorization: Bearer {{access_token}}
HTTP 200
[Asserts]
body contains "Sequencer Viewer"
body contains "#commit"
body contains "{{did}}"

GET {{base_url}}/account/firehose
Authorization: Bearer {{access_token}}
HTTP 200
[Asserts]
body contains "Firehose Viewer"
body contains "com.atproto.sync.subscribeRepos"
body contains "Recent decoded frames"
