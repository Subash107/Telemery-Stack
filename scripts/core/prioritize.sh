#!/bin/bash
set -euo pipefail

result_dir="${1:?Usage: prioritize.sh <result_dir>}"
input="$result_dir/nuclei.txt"
output="$result_dir/prioritized.txt"

> "$output"
while IFS= read -r finding || [[ -n "$finding" ]]; do
  printf '[Priority:5] %s\n' "$finding" >> "$output"
done < "$input"
