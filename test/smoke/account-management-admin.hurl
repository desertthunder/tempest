# Admin control panel browser UI: login, dashboard, accounts, personal backups.
#
# Verifies: unauthenticated redirect, admin login form with DID display,
# authenticated dashboard, accounts list, personal backups pages, and logout.
#
# Uses browser session cookies.
#
# Required variables: base_url, admin_did, admin_identifier, admin_password
#
# Scope: local + deployed (requires admin account configured)

GET {{base_url}}/admin
HTTP 302
[Asserts]
header "location" contains "/admin/login"

GET {{base_url}}/admin/login?return_to=/admin
HTTP 200
[Captures]
admin_csrf: xpath "string(//input[@name='_csrf_token']/@value)"
[Asserts]
body contains "admin-login-form"
body contains "{{admin_did}}"

POST {{base_url}}/admin/login
[FormParams]
_csrf_token: {{admin_csrf}}
return_to: /admin
admin[identifier]: {{admin_identifier}}
admin[password]: {{admin_password}}
HTTP 302
[Asserts]
header "location" == "/admin"

GET {{base_url}}/admin
HTTP 200
[Asserts]
body contains "admin-dashboard"
body contains "Admin Dashboard"

GET {{base_url}}/admin/accounts
HTTP 200
[Asserts]
body contains "admin-account-table"

GET {{base_url}}/account
HTTP 302
[Asserts]
header "location" contains "/account/login"

GET {{base_url}}/admin/personal-backups
HTTP 200
[Asserts]
body contains "personal-backup-account-table"
body contains "External Account Backups"

GET {{base_url}}/admin/personal-backups/new
HTTP 200
[Asserts]
body contains "personal-backup-create-form"
body contains "Register External Backup Account"
body not contains "{{admin_password}}"

GET {{base_url}}/admin/logout
HTTP 302
[Asserts]
header "location" == "/"

GET {{base_url}}/admin/personal-backups
HTTP 302
[Asserts]
header "location" contains "/admin/login"
