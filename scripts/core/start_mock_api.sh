#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/config.sh"

load_project_env

export MOCK_API_USERNAME="${MOCK_API_USERNAME:-${API_USERNAME:-}}"
export MOCK_API_PASSWORD="${MOCK_API_PASSWORD:-${API_PASSWORD:-}}"

require_env_var MOCK_API_USERNAME
require_env_var MOCK_API_PASSWORD

mapfile -t api_parts < <(python3 - <<'PY' "$API_URL" "$MOCK_API_BIND_HOST" "$MOCK_API_BIND_PORT"
import sys
from urllib.parse import urlparse

parsed = urlparse(sys.argv[1])
host = sys.argv[2] or "127.0.0.1"
port = sys.argv[3] or str(parsed.port or (443 if parsed.scheme == "https" else 80))
base_path = parsed.path.rstrip("/") or "/"

print(host)
print(port)
print(base_path)
PY
)

host="${api_parts[0]}"
port="${api_parts[1]}"
base_path="${api_parts[2]}"
grpc_host="${MOCK_API_GRPC_BIND_HOST:-127.0.0.1}"
grpc_port="${MOCK_API_GRPC_BIND_PORT:-50061}"
mock_api_script="$SCRIPT_DIR/mock_six_api.py"

case "$host" in
  127.0.0.1|localhost|0.0.0.0)
    ;;
  *)
    echo "Refusing to bind the mock API to a non-local host: $host" >&2
    exit 1
    ;;
esac

case "$grpc_host" in
  127.0.0.1|localhost|0.0.0.0)
    ;;
  *)
    echo "Refusing to bind the mock gRPC API to a non-local host: $grpc_host" >&2
    exit 1
    ;;
esac

if [[ ! -f "$mock_api_script" ]]; then
  echo "Mock API implementation not found: $mock_api_script" >&2
  echo "This checkout contains the simulation launcher, but not the mock API server file." >&2
  exit 1
fi

exec python3 "$mock_api_script" \
  --host "$host" \
  --port "$port" \
  --base-path "$base_path" \
  --grpc-host "$grpc_host" \
  --grpc-port "$grpc_port" \
  --storage-dir "$(resolve_project_path "$MOCK_STORAGE_DIR")" \
  --username "$MOCK_API_USERNAME" \
  --password "$MOCK_API_PASSWORD"
