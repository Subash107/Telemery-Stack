#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/config.sh"

load_project_env

started_at="${PIPELINE_METRICS_STARTED_AT:?Missing PIPELINE_METRICS_STARTED_AT}"
finished_at="${PIPELINE_METRICS_FINISHED_AT:?Missing PIPELINE_METRICS_FINISHED_AT}"
exit_code="${PIPELINE_METRICS_EXIT_CODE:?Missing PIPELINE_METRICS_EXIT_CODE}"
targets_processed="${PIPELINE_METRICS_TARGETS_PROCESSED:-0}"
results_created="${PIPELINE_METRICS_RESULTS_CREATED:-0}"
archives_created="${PIPELINE_METRICS_ARCHIVES_CREATED:-0}"
upload_attempts="${PIPELINE_METRICS_UPLOAD_ATTEMPTS:-0}"
upload_failures="${PIPELINE_METRICS_UPLOAD_FAILURES:-0}"

metrics_dir="$(resolve_project_path "$PIPELINE_METRICS_DIR")"
metrics_file="$metrics_dir/$PIPELINE_METRICS_FILE"
tmp_file="$metrics_file.tmp"

duration_seconds=$((finished_at - started_at))
if (( duration_seconds < 0 )); then
  duration_seconds=0
fi

success=1
if (( exit_code != 0 )); then
  success=0
fi

escape_label_value() {
  local value="$1"

  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '%s' "$value"
}

env_label="$(escape_label_value "$ENV")"
workflow_label="$(escape_label_value "$WORKFLOW_MODE")"

mkdir -p "$metrics_dir"

cat > "$tmp_file" <<EOF
# HELP bbp_pipeline_info Static metadata for the BBP pipeline metrics snapshot.
# TYPE bbp_pipeline_info gauge
bbp_pipeline_info{env="$env_label",workflow_mode="$workflow_label"} 1
# HELP bbp_pipeline_last_run_timestamp_seconds Unix timestamp of the last completed BBP pipeline run.
# TYPE bbp_pipeline_last_run_timestamp_seconds gauge
bbp_pipeline_last_run_timestamp_seconds $finished_at
# HELP bbp_pipeline_last_run_started_at_seconds Unix timestamp of the last BBP pipeline start.
# TYPE bbp_pipeline_last_run_started_at_seconds gauge
bbp_pipeline_last_run_started_at_seconds $started_at
# HELP bbp_pipeline_last_run_duration_seconds Duration of the last BBP pipeline run in seconds.
# TYPE bbp_pipeline_last_run_duration_seconds gauge
bbp_pipeline_last_run_duration_seconds $duration_seconds
# HELP bbp_pipeline_last_run_success Whether the most recent BBP pipeline run succeeded.
# TYPE bbp_pipeline_last_run_success gauge
bbp_pipeline_last_run_success $success
# HELP bbp_pipeline_last_run_exit_code Exit code of the most recent BBP pipeline run.
# TYPE bbp_pipeline_last_run_exit_code gauge
bbp_pipeline_last_run_exit_code $exit_code
# HELP bbp_pipeline_last_run_targets Number of targets processed in the most recent run.
# TYPE bbp_pipeline_last_run_targets gauge
bbp_pipeline_last_run_targets $targets_processed
# HELP bbp_pipeline_last_run_results Number of result directories created in the most recent run.
# TYPE bbp_pipeline_last_run_results gauge
bbp_pipeline_last_run_results $results_created
# HELP bbp_pipeline_last_run_archives Number of archives created in the most recent run.
# TYPE bbp_pipeline_last_run_archives gauge
bbp_pipeline_last_run_archives $archives_created
# HELP bbp_pipeline_last_run_upload_attempts Number of upload attempts in the most recent run.
# TYPE bbp_pipeline_last_run_upload_attempts gauge
bbp_pipeline_last_run_upload_attempts $upload_attempts
# HELP bbp_pipeline_last_run_upload_failures Number of upload failures in the most recent run.
# TYPE bbp_pipeline_last_run_upload_failures gauge
bbp_pipeline_last_run_upload_failures $upload_failures
EOF

mv "$tmp_file" "$metrics_file"
printf '%s\n' "$metrics_file"
