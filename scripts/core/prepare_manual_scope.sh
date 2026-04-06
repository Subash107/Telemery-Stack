#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/config.sh"

load_project_env

targets_file="$(resolve_project_path "$TARGETS_FILE")"
results_root="$(resolve_project_path "$MANUAL_RESULTS_DIR")"

mkdir -p "$results_root"

sanitize_target() {
  printf '%s' "$1" | sed 's#[/:]#_#g'
}

write_if_missing() {
  local file_path="$1"

  if [[ -f "$file_path" ]]; then
    return 0
  fi

  mkdir -p "$(dirname "$file_path")"
  cat > "$file_path"
}

while IFS= read -r raw_target || [[ -n "$raw_target" ]]; do
  target="$(printf '%s' "$raw_target" | tr -d '\r')"
  [[ -z "$target" || "$target" =~ ^# ]] && continue

  safe_target="$(sanitize_target "$target")"
  result_dir="$results_root/$safe_target"
  base_url="${TARGET_SCHEME}://$target"
  entry_url="$base_url${TARGET_ENTRY_PATH}"
  helper_file="$result_dir/gitbash-helpers.sh"
  notes_file="$result_dir/manual-notes.md"
  draft_file="$result_dir/finding-draft.md"
  burp_file="$result_dir/burp-setup.md"
  scope_file="$result_dir/scope-summary.md"
  seed_file="$result_dir/seed-urls.txt"

  mkdir -p "$result_dir/evidence" "$result_dir/requests" "$result_dir/reports"

  cat > "$scope_file" <<EOF
# Manual Scope Summary

- Scope host: $base_url
- Observed public entry path: $entry_url
- Manual traffic only: do not run automated scanners, Intruder sprays, Nuclei, sqlmap, or Burp Scanner.
- User-Agent rule: append the string \`bugbounty\` to HTTP(S) requests.
- Account rule: only use accounts you own or that were explicitly granted to you.
- Data handling rule: stop immediately if you encounter PII or customer data, purge local copies, and report it.
- Safety rule: no brute force, no service degradation, no post-exploitation, no persistence.
- Workspace folders:
  - \`requests/\` for saved raw requests
  - \`evidence/\` for screenshots and response captures
  - \`reports/\` for finished writeups
EOF

  cat > "$burp_file" <<EOF
# Burp Setup

1. Add only \`$target\` to Burp target scope.
2. Add a request header rule so your User-Agent contains \`bugbounty\`.
3. Keep Intercept off unless you are actively modifying one request.
4. Use Repeater and Comparer for manual verification.
5. Leave Burp Scanner and large Intruder jobs disabled for this target.
6. Save useful requests into \`requests/\`.
7. Save evidence into \`evidence/\`.
EOF

  write_if_missing "$notes_file" <<EOF
# Manual Notes

## Target
- Host: $base_url
- Entry URL: $entry_url
- Test date:
- Account used:

## Endpoints
- $base_url/
- $entry_url

## Observations
- 

## Candidate Findings
1. 
2. 
3. 

## Cleanup Notes
- 
EOF

  write_if_missing "$draft_file" <<EOF
# Finding Draft

Use one file per vulnerability.
Do not submit scanner output, open ports, or header-only findings without real exploitability.

## Metadata

- Title:
- Asset: $target
- Product / Platform:
- Version / Build:
- Entry URL:
- Vulnerability Type:
- Severity Guess:
- Attack Vector:
- Privileges Required:
- User Interaction Required:
- Testing Account:
- Date Tested:

## Summary

Write 3 to 5 lines that explain:
- what the bug is
- where it is
- why it matters

## Scope And Preconditions

- Why this asset is in scope:
- Starting state:
- Required permissions:
- Notes about test data:

## Reproduction

1.
2.
3.
4.
5.

## Evidence

### Request

\`\`\`http
\`\`\`

### Response

\`\`\`http
\`\`\`

### Screenshots / Files

- Screenshot:
- HAR / video:
- Local evidence path:

## Observed Result

-

## Expected Secure Result

-

## Impact

- Confidentiality:
- Integrity:
- Availability:
- Real attacker outcome:
- Business impact:

## Exploit Scenario

1.
2.
3.

## Why This Is Not Out Of Scope

- Not only a missing header:
- Not only an open port:
- Not only weak TLS:
- Not only self-XSS:
- Concrete exploit path:

## Recommended Fix

- Primary fix:
- Defense-in-depth:

## Cleanup

- Delete uploaded files:
- Remove created objects:
- Revert changed state:
EOF

  cat > "$seed_file" <<EOF
$base_url/
$entry_url
EOF

  cat > "$helper_file" <<EOF
#!/bin/bash

export BBP_TARGET_ROOT="$base_url"
export BBP_ENTRY_URL="$entry_url"
export BBP_BURP_PROXY="$BURP_PROXY"
export BBP_USER_AGENT="$BUGBOUNTY_USER_AGENT"

bbp_curl() {
  curl --proxy "\$BBP_BURP_PROXY" --user-agent "\$BBP_USER_AGENT" --path-as-is --include --silent --show-error "\$@"
}

cat <<'INFO'
Loaded manual testing helpers.

- Target root: $base_url
- Entry URL: $entry_url
- Burp proxy: $BURP_PROXY
- User-Agent contains: bugbounty

Examples:
  bbp_curl "\$BBP_TARGET_ROOT/"
  bbp_curl "\$BBP_ENTRY_URL"
INFO
EOF

  chmod +x "$helper_file"
  printf 'Prepared manual workspace: %s\n' "$result_dir"
done < "$targets_file"
