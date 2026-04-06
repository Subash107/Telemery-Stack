#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/config.sh"

load_project_env

python3 "$SCRIPT_DIR/python_db.py" init "$(resolve_project_path "$DB_PATH")"
