GET {{base_url}}/xrpc/_health
HTTP 200
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.version" exists
jsonpath "$.status" == "ok"
