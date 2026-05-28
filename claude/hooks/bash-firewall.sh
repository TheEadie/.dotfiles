#!/usr/bin/env bash
set -euo pipefail

cmd=$(jq -r '.tool_input.command // ""')

deny_patterns=(
  'rm\s+-rf\s+/'
  'git\s+push\s+--force.*main'
  'curl\s+http[^s]'
  'sudo\s+rm'
  'chmod\s+777'
  'DROP\s+TABLE'
)

for pat in "${deny_patterns[@]}"; do
  if echo "$cmd" | grep -Eiq "$pat"; then
    echo "Blocked: command matches denied pattern '$pat'. Use a safer alternative." >&2
    exit 2
  fi
done

exit 0
