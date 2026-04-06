#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/config.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/api_client.sh"

load_project_env

archive_path="${1:?Usage: upload_results.sh <archive_path> <program> [token]}"
program="${2:?Usage: upload_results.sh <archive_path> <program> [token]}"
token="${3:-}"

if [[ -z "$token" ]]; then
  token="$(api_login)"
fi

api_upload_archive "$archive_path" "$program" "$token"
