#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/config.sh"

load_project_env

input_dir="${1:?Usage: db_insert.sh <result_dir> <program>}"
program="${2:?Usage: db_insert.sh <result_dir> <program>}"
prioritized_file="$(resolve_project_path "$input_dir/prioritized.txt")"

python3 "$SCRIPT_DIR/python_db.py" insert \
  "$(resolve_project_path "$DB_PATH")" \
  "$prioritized_file" \
  "$program"
