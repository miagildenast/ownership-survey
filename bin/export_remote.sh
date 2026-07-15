#!/usr/bin/env bash
# Server-side study export worker. Runs ON the server (invoked over SSH by
# bin/export.sh). Loads the prod env from the supervisord service file and writes
# the export JSON to the given path via the release's `eval` — no running node /
# epmd needed. Don't call this from your laptop; use bin/export.sh.
#
#     ./bin/export_remote.sh <all|in_progress|completed|aborted> <output_path>
#     ./bin/export_remote.sh --session-id <session_id> <output_path>
#     ./bin/export_remote.sh --case-id <case_id> <output_path>
#     ./bin/export_remote.sh --case-number <case_number> <output_path>
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/_build/prod/rel/ownership_ash_chat/bin/ownership_ash_chat"

case "${1:-all}" in
  --session-id)
    id="${2:?--session-id requires a value}"
    output="${3:?output path required}"
    arg="{:session_id, \"$id\"}"
    ;;
  --case-id)
    id="${2:?--case-id requires a value}"
    output="${3:?output path required}"
    arg="{:case_id, \"$id\"}"
    ;;
  --case-number)
    id="${2:?--case-number requires a value}"
    output="${3:?output path required}"
    arg="{:case_number, \"$id\"}"
    ;;
  all)         output="${2:?output path required}"; arg="nil" ;;
  in_progress) output="${2:?output path required}"; arg=":in_progress" ;;
  completed)   output="${2:?output path required}"; arg=":completed" ;;
  aborted)     output="${2:?output path required}"; arg=":aborted" ;;
  *)
    echo "Unknown selector '$1' (use: all|in_progress|completed|aborted|--session-id <id>|--case-id <id>|--case-number <n>)" >&2
    exit 1
    ;;
esac

# The supervisord service file is the single source of truth for prod env.
INI="${SERVICE_INI:-$HOME/etc/services.d/ownership_ash_chat.ini}"
[ -f "$INI" ] || INI="$ROOT/bin/ownership_ash_chat.ini"

# Parse the `environment=` block (KEY="val", lines) into real exports.
eval "$(awk -F= '
  /^[[:space:]]+[A-Z_]+=/ {
    key = $1; sub(/^[[:space:]]+/, "", key)
    val = substr($0, index($0, "=") + 1); sub(/,[[:space:]]*$/, "", val)
    print "export " key "=" val
  }' "$INI")"

"$BIN" eval "OwnershipAshChat.Release.export(\"$output\", $arg)"
