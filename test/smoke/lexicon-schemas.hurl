POST {{base_url}}/xrpc/com.atproto.server.createAccount
Content-Type: application/json
{
  "handle": "lexicon-{{newUuid}}.test",
  "email": "lexicon-{{newUuid}}@example.com",
  "password": "correct horse battery staple"
}
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
  "collection": "com.atproto.lexicon.schema",
  "rkey": "example.lexicon.smoke",
  "record": {
    "$type": "com.atproto.lexicon.schema",
    "lexicon": 1
  }
}
HTTP 200
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.validationStatus" == "valid"

POST {{base_url}}/xrpc/com.atproto.repo.createRecord
Authorization: Bearer {{access_token}}
Content-Type: application/json
{
  "repo": "{{created_did}}",
  "collection": "example.lexicon.smoke",
  "rkey": "one",
  "record": {
    "$type": "example.lexicon.smoke",
    "text": "optimistic unknown"
  }
}
HTTP 200
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.validationStatus" == "unknown"

POST {{base_url}}/xrpc/com.atproto.repo.createRecord
Authorization: Bearer {{access_token}}
Content-Type: application/json
{
  "repo": "{{created_did}}",
  "collection": "example.lexicon.strict",
  "rkey": "one",
  "validate": true,
  "record": {
    "$type": "example.lexicon.strict",
    "text": "strict unknown"
  }
}
HTTP 400
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.error" == "InvalidRequest"
