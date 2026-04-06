#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/config.sh"

load_project_env

input_dir="${1:?Usage: package_results.sh <result_dir> [archive_label]}"
archive_label="${2:-$(basename "$input_dir")}"

resolved_input_dir="$(resolve_project_path "$input_dir")"
artifacts_dir="$(resolve_project_path "$ARTIFACTS_DIR")"
archive_path="$artifacts_dir/${archive_label}-${ENV}.zip"

mkdir -p "$artifacts_dir"

python3 - <<'PY' "$resolved_input_dir" "$archive_path"
import sys
import zipfile
from pathlib import Path

source_dir = Path(sys.argv[1]).resolve()
archive_path = Path(sys.argv[2]).resolve()

with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED) as bundle:
    for path in sorted(source_dir.rglob("*")):
        if path.is_file():
            bundle.write(path, arcname=str(Path(source_dir.name) / path.relative_to(source_dir)))
PY

printf '%s\n' "$archive_path"
