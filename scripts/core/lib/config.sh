#!/bin/bash

CONFIG_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$CONFIG_LIB_DIR/../../.." && pwd)"
PROJECT_ENV_KEYS=(
  ENV
  ENV_FILE
  WORKFLOW_MODE
  API_RUNTIME_CONTEXT
  API_URL
  API_SCHEME
  API_HOST
  API_LOCAL_HOST
  API_DOCKER_HOST
  API_PORT
  API_BASE_PATH
  API_HEALTH_PATH
  API_LOGIN_PATH
  API_UPLOAD_PATH
  API_TIMEOUT_SECONDS
  MOCK_API_BIND_HOST
  MOCK_API_BIND_PORT
  MOCK_API_GRPC_BIND_HOST
  MOCK_API_GRPC_BIND_PORT
  MOCK_API_USERNAME
  MOCK_API_PASSWORD
  TARGET_SCHEME
  TARGET_ENTRY_PATH
  BURP_PROXY
  BUGBOUNTY_USER_AGENT
  TARGETS_FILE
  MANUAL_RESULTS_DIR
  DB_PATH
  RESULTS_DIR
  ARTIFACTS_DIR
  MOCK_STORAGE_DIR
  ENABLE_PACKAGING
  ENABLE_API_SYNC
  ENABLE_PIPELINE_METRICS
  PIPELINE_METRICS_DIR
  PIPELINE_METRICS_FILE
  API_USERNAME
  API_PASSWORD
)

capture_runtime_env_overrides() {
  local name override_name

  for name in "${PROJECT_ENV_KEYS[@]}"; do
    if [[ -n "${!name+x}" ]]; then
      override_name="__BBP_RUNTIME_OVERRIDE_${name}"
      printf -v "$override_name" '%s' "${!name}"
      export "$override_name"
    fi
  done
}

restore_runtime_env_overrides() {
  local name override_name

  for name in "${PROJECT_ENV_KEYS[@]}"; do
    override_name="__BBP_RUNTIME_OVERRIDE_${name}"
    if [[ -n "${!override_name+x}" ]]; then
      printf -v "$name" '%s' "${!override_name}"
      export "$name"
      unset "$override_name"
    fi
  done
}

running_in_docker() {
  if [[ -f "/.dockerenv" ]]; then
    return 0
  fi

  grep -qaE 'docker|containerd|kubepods' /proc/1/cgroup 2>/dev/null
}

detect_api_runtime_context() {
  case "${API_RUNTIME_CONTEXT:-auto}" in
    auto|"")
      if running_in_docker; then
        printf 'docker\n'
      else
        printf 'local\n'
      fi
      ;;
    local|docker)
      printf '%s\n' "$API_RUNTIME_CONTEXT"
      ;;
    *)
      printf 'local\n'
      ;;
  esac
}

resolve_docker_api_host() {
  if [[ -n "${API_DOCKER_HOST:-}" ]]; then
    printf '%s\n' "$API_DOCKER_HOST"
    return 0
  fi

  python3 - <<'PY'
import socket
import struct

try:
    socket.gethostbyname("host.docker.internal")
except OSError:
    try:
        with open("/proc/net/route", encoding="utf-8") as handle:
            next(handle)
            for line in handle:
                fields = line.strip().split()
                if len(fields) >= 3 and fields[1] == "00000000":
                    gateway = fields[2]
                    address = socket.inet_ntoa(struct.pack("<L", int(gateway, 16)))
                    print(address)
                    break
            else:
                print("172.17.0.1")
    except OSError:
        print("172.17.0.1")
else:
    print("host.docker.internal")
PY
}

build_api_url() {
  local scheme host port base_path runtime_context default_port

  scheme="${API_SCHEME:-http}"
  host="${API_HOST:-auto}"
  port="${API_PORT:-18080}"
  base_path="${API_BASE_PATH:-/mock-six-api}"
  runtime_context="$(detect_api_runtime_context)"

  if [[ "$host" == "auto" ]]; then
    if [[ "$runtime_context" == "docker" ]]; then
      host="$(resolve_docker_api_host)"
    else
      host="${API_LOCAL_HOST:-localhost}"
    fi
  fi

  base_path="/${base_path#/}"
  default_port="80"
  if [[ "$scheme" == "https" ]]; then
    default_port="443"
  fi

  if [[ "$port" == "$default_port" ]]; then
    printf '%s://%s%s\n' "$scheme" "$host" "$base_path"
  else
    printf '%s://%s:%s%s\n' "$scheme" "$host" "$port" "$base_path"
  fi
}

find_env_file() {
  if [[ -n "${ENV_FILE:-}" ]]; then
    printf '%s\n' "$ENV_FILE"
    return 0
  fi

  if [[ -n "${ENV:-}" && -f "$PROJECT_ROOT/.env.$ENV" ]]; then
    printf '%s\n' "$PROJECT_ROOT/.env.$ENV"
    return 0
  fi

  if [[ -f "$PROJECT_ROOT/.env" ]]; then
    printf '%s\n' "$PROJECT_ROOT/.env"
    return 0
  fi

  printf ''
}

load_project_env() {
  local env_file
  local requested_env="${ENV:-}"
  capture_runtime_env_overrides
  env_file="$(find_env_file)"

  if [[ -n "$env_file" ]]; then
    set -a
    # shellcheck disable=SC1090
    . "$env_file"
    set +a
  fi

  restore_runtime_env_overrides

  if [[ -n "$requested_env" ]]; then
    ENV="$requested_env"
  fi

  : "${ENV:=dev}"
  : "${WORKFLOW_MODE:=manual}"
  : "${API_RUNTIME_CONTEXT:=auto}"
  : "${API_URL:=auto}"
  : "${API_SCHEME:=http}"
  : "${API_HOST:=auto}"
  : "${API_LOCAL_HOST:=localhost}"
  : "${API_PORT:=18080}"
  : "${API_BASE_PATH:=/mock-six-api}"
  : "${API_HEALTH_PATH:=/health}"
  : "${API_LOGIN_PATH:=/login}"
  : "${API_UPLOAD_PATH:=/upload}"
  : "${API_TIMEOUT_SECONDS:=15}"
  : "${MOCK_API_BIND_HOST:=127.0.0.1}"
  : "${MOCK_API_BIND_PORT:=$API_PORT}"
  : "${MOCK_API_GRPC_BIND_HOST:=127.0.0.1}"
  : "${MOCK_API_GRPC_BIND_PORT:=50061}"
  : "${TARGET_SCHEME:=https}"
  : "${TARGET_ENTRY_PATH:=/member_section/}"
  : "${BURP_PROXY:=http://127.0.0.1:8080}"
  : "${BUGBOUNTY_USER_AGENT:=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) bugbounty}"
  : "${TARGETS_FILE:=targets/programs.txt}"
  : "${MANUAL_RESULTS_DIR:=results}"
  : "${DB_PATH:=database/findings.db}"
  : "${RESULTS_DIR:=results}"
  : "${ARTIFACTS_DIR:=artifacts}"
  : "${MOCK_STORAGE_DIR:=mock_api_uploads}"
  : "${ENABLE_PACKAGING:=false}"
  : "${ENABLE_API_SYNC:=false}"
  : "${ENABLE_PIPELINE_METRICS:=false}"
  : "${PIPELINE_METRICS_DIR:=ops/observability/data/node-exporter/textfile}"
  : "${PIPELINE_METRICS_FILE:=bbp_pipeline.prom}"

  if [[ "$API_URL" == "auto" ]]; then
    API_URL="$(build_api_url)"
  fi

  API_URL="${API_URL%/}"
  API_BASE_PATH="/${API_BASE_PATH#/}"
}

resolve_project_path() {
  local path="$1"

  if [[ "$path" = /* || "$path" =~ ^[A-Za-z]:\\ ]]; then
    printf '%s\n' "$path"
    return 0
  fi

  printf '%s\n' "$PROJECT_ROOT/$path"
}

require_env_var() {
  local name="$1"

  if [[ -z "${!name:-}" ]]; then
    echo "Missing required environment variable: $name" >&2
    exit 1
  fi
}

bool_enabled() {
  case "${1,,}" in
    1|true|yes|on)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}
