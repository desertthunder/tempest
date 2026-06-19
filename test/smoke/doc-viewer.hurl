GET {{base_url}}/docs
HTTP 200
[Asserts]
header "content-type" contains "text/html"
body contains "Tempest Navigator 4.0 - Reference Documentation"
body contains "id=\"doc-bookmarks\""
body contains "id=\"doc-content\""
body contains "href=\"/docs/architecture\""
body contains "Best viewed in Tempest Navigator"

GET {{base_url}}/docs/architecture
HTTP 200
[Asserts]
header "content-type" contains "text/html"
body contains "Architecture"
body contains "Reference file: architecture.md"
body contains "Concepts"
body contains "<pre><code"
body contains "<table>"
body contains "href=\"/docs/admin-operations\""

GET {{base_url}}/docs/not-a-real-doc
HTTP 404

GET {{base_url}}/docs/..%2F..%2Fconfig%2Fprod.exs
HTTP 400
[Asserts]
body not contains "SECRET_KEY_BASE"

GET {{base_url}}/docs/..%252F..%252Fconfig%252Fprod.exs
HTTP 404
[Asserts]
body not contains "SECRET_KEY_BASE"
body not contains "TempestWeb.Endpoint"
