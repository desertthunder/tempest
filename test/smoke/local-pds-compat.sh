#!/usr/bin/env bash
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
