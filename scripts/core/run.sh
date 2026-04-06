#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/config.sh"

load_project_env

case "${WORKFLOW_MODE,,}" in
  manual)
    bash "$SCRIPT_DIR/prepare_manual_scope.sh"
    exit 0
    ;;
  simulation|sim|mock)
    ;;
  *)
    echo "Unsupported WORKFLOW_MODE: $WORKFLOW_MODE" >&2
    echo "Use WORKFLOW_MODE=manual or WORKFLOW_MODE=simulation." >&2
    exit 1
    ;;
esac

# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/api_client.sh"

start_time="$(date +%s)"
processed_targets=0
result_dirs_created=0
archives_created=0
upload_attempts=0
upload_failures=0

write_pipeline_metrics() {
  local exit_code="$1"

  if ! bool_enabled "$ENABLE_PIPELINE_METRICS"; then
    return 0
  fi

  PIPELINE_METRICS_STARTED_AT="$start_time" \
  PIPELINE_METRICS_FINISHED_AT="$(date +%s)" \
  PIPELINE_METRICS_EXIT_CODE="$exit_code" \
  PIPELINE_METRICS_TARGETS_PROCESSED="$processed_targets" \
  PIPELINE_METRICS_RESULTS_CREATED="$result_dirs_created" \
  PIPELINE_METRICS_ARCHIVES_CREATED="$archives_created" \
  PIPELINE_METRICS_UPLOAD_ATTEMPTS="$upload_attempts" \
  PIPELINE_METRICS_UPLOAD_FAILURES="$upload_failures" \
    bash "$SCRIPT_DIR/write_pipeline_metrics.sh" > /dev/null
}

trap 'exit_code=$?; write_pipeline_metrics "$exit_code"' EXIT

targets_file="$(resolve_project_path "$TARGETS_FILE")"
results_root="$(resolve_project_path "$RESULTS_DIR")"
mkdir -p "$results_root"

bash "$SCRIPT_DIR/init_db.sh"

api_token=""
if bool_enabled "$ENABLE_API_SYNC"; then
  echo "Checking API health at $API_URL$API_HEALTH_PATH"
  api_healthcheck > /dev/null
  api_token="$(api_login)"
fi

while IFS= read -r target || [[ -n "$target" ]]; do
  [[ -z "$target" ]] && continue

  ((processed_targets += 1))
  safe_target="$(printf '%s' "$target" | sed 's#[/:]#_#g')"
  result_dir="$results_root/$safe_target"
  mkdir -p "$result_dir"
  ((result_dirs_created += 1))

  printf 'http://%s\n' "$target" > "$result_dir/live_hosts.txt"
  printf 'Critical vuln AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H\n' > "$result_dir/nuclei.txt"

  bash "$SCRIPT_DIR/prioritize.sh" "$result_dir"
  bash "$SCRIPT_DIR/deduplicate.sh" "$result_dir/prioritized.txt" "$result_dir/clean.txt"
  mv "$result_dir/clean.txt" "$result_dir/prioritized.txt"
  bash "$SCRIPT_DIR/db_insert.sh" "$result_dir" "$target"

  if bool_enabled "$ENABLE_PACKAGING"; then
    archive_path="$(bash "$SCRIPT_DIR/package_results.sh" "$result_dir" "$safe_target")"
    ((archives_created += 1))

    if bool_enabled "$ENABLE_API_SYNC"; then
      ((upload_attempts += 1))

      if bash "$SCRIPT_DIR/upload_results.sh" "$archive_path" "$target" "$api_token" > "$result_dir/api_upload_receipt.json"; then
        :
      else
        ((upload_failures += 1))
        exit 1
      fi
    fi
  fi
done < "$targets_file"
