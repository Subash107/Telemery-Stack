#!/bin/bash
set -euo pipefail

input_file="${1:?Usage: deduplicate.sh <input_file> <output_file>}"
output_file="${2:?Usage: deduplicate.sh <input_file> <output_file>}"

sort "$input_file" | uniq > "$output_file"
