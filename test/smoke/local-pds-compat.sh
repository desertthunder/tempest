#!/usr/bin/env bash
#
# local-pds-compat.sh — zero-config local PDS compatibility smoke profile.
#
# Runs a curated subset of hurl smoke tests that self-generate account data via
# hurl's built-in {{newUuid}} function, so no external variables are required
# beyond base_url.
#
# This is the simplest way to verify a running Tempest instance handles core PDS flows
# such as baseline CRUD, compatibility extras, OAuth error paths, and migration lifecycle.
#
# For broader coverage (identity, blobs, firehose, records, etc.) use the full
# quick-local-run batch in test/smoke/README.md, which requires operator-supplied
# account variables.
#
# Usage:
#   mix phx.server
#   test/smoke/local-pds-compat.sh http://localhost:4000
#
# Or with an env var:
#   BASE_URL=http://localhost:4000 test/smoke/local-pds-compat.sh
#
set -euo pipefail

base_url="${BASE_URL:-${1:-http://localhost:4000}}"

if ! command -v hurl >/dev/null 2>&1; then
    echo "error: hurl is required to run the local PDS compatibility smoke profile" >&2
    exit 127
fi

hurl --test --jobs 1 \
    --variable "base_url=${base_url}" \
    test/smoke/tempest_basic.hurl \
    test/smoke/tempest_compat.hurl \
    test/smoke/oauth-security.hurl \
    test/smoke/migration-lifecycle.hurl
