GET {{base_url}}/xrpc/_stats
HTTP 200
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.status" exists
jsonpath "$.version" exists
jsonpath "$.generatedAt" exists
jsonpath "$.uptimeSeconds" exists
jsonpath "$.metrics.hostedAccountCount" exists
jsonpath "$.metrics.totalAccountCount" exists
jsonpath "$.metrics.commitCount" exists
jsonpath "$.metrics.collectionCount" exists
jsonpath "$.metrics.recordCount" exists
jsonpath "$.metrics.lastIndexedAt" exists
jsonpath "$.health.status" exists
jsonpath "$.health.checks.storageWritable" exists
jsonpath "$.health.checks.accountDatabase" exists
jsonpath "$.health.checks.sequencerDatabase" exists
jsonpath "$.health.checks.repoDirectory" exists
jsonpath "$.health.checks.blobDirectory" exists
jsonpath "$.health.checks.sequencerReadable" exists
jsonpath "$.health.checks.tornWriteCount" exists
jsonpath "$.health.checks.statsScanErrorCount" exists
jsonpath "$.users" exists
jsonpath "$.latestRecord" exists
jsonpath "$.commitWeeks[0].weekStart" exists
jsonpath "$.commitWeeks[0].weekEnd" exists
jsonpath "$.commitWeeks[0].commitCount" exists
jsonpath "$.commitWeeks[3].weekStart" exists
jsonpath "$.commitWeeks[4]" not exists
jsonpath "$.collections" exists
jsonpath "$.email" not exists
jsonpath "$.token" not exists
jsonpath "$.session" not exists
jsonpath "$.oauth" not exists
jsonpath "$.backup" not exists
jsonpath "$.admin" not exists
jsonpath "$.record_json" not exists

GET {{base_url}}/stats
HTTP 200
[Asserts]
header "content-type" contains "text/html"
body contains "Tempest Public Stats"
body contains "Hosted Accounts"
body contains "Commits"
body contains "Collections"
body contains "Records"
body contains "Last Indexed"
body contains "Uptime"
body contains "Health"
body contains "Users"
body contains "Latest Indexed Record"
body contains "Weekly Commits"
body contains "id=\"collection-summaries\""
body contains "commit-histogram__bar"

GET {{base_url}}/xrpc/_admin/status
HTTP 401
[Asserts]
header "content-type" contains "application/json"
jsonpath "$.error" == "AuthenticationRequired"
