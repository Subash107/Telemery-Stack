#!/bin/bash

API_CLIENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
. "$API_CLIENT_DIR/config.sh"

urlencode() {
  python3 - <<'PY' "$1"
import sys
from urllib.parse import quote

print(quote(sys.argv[1], safe=""))
PY
}

sha256_file() {
  python3 - <<'PY' "$1"
import hashlib
import sys

path = sys.argv[1]
digest = hashlib.sha256()

with open(path, "rb") as handle:
    for chunk in iter(lambda: handle.read(65536), b""):
        digest.update(chunk)

print(digest.hexdigest())
PY
}

api_healthcheck() {
  curl -fsS \
    --connect-timeout "$API_TIMEOUT_SECONDS" \
    --max-time "$((API_TIMEOUT_SECONDS * 2))" \
    "$API_URL$API_HEALTH_PATH"
}

api_login() {
  local body response

  require_env_var API_USERNAME
  require_env_var API_PASSWORD

  body="$(python3 - <<'PY' "$API_USERNAME" "$API_PASSWORD"
import json
import sys

print(json.dumps({"username": sys.argv[1], "password": sys.argv[2]}))
PY
)"

  response="$(curl -fsS \
    --connect-timeout "$API_TIMEOUT_SECONDS" \
    --max-time "$((API_TIMEOUT_SECONDS * 2))" \
    -H "Content-Type: application/json" \
    -X POST \
    --data "$body" \
    "$API_URL$API_LOGIN_PATH")"

  python3 - <<'PY' "$response"
import json
import sys

print(json.loads(sys.argv[1])["access_token"])
PY
}

api_upload_archive() {
  local archive_path program token filename file_sha upload_url

  archive_path="$(resolve_project_path "$1")"
  program="$2"
  token="$3"

  if [[ ! -f "$archive_path" ]]; then
    echo "Archive not found: $archive_path" >&2
    exit 1
  fi

  filename="$(basename "$archive_path")"
  file_sha="$(sha256_file "$archive_path")"
  upload_url="$API_URL$API_UPLOAD_PATH?program=$(urlencode "$program")&filename=$(urlencode "$filename")&sha256=$file_sha"

  curl -fsS \
    --connect-timeout "$API_TIMEOUT_SECONDS" \
    --max-time "$((API_TIMEOUT_SECONDS * 2))" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/zip" \
    -X PUT \
    --data-binary "@$archive_path" \
    "$upload_url"
}
