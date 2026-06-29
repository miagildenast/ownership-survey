#!/usr/bin/env bash
# Server-side study export worker. Runs ON the server (invoked over SSH by
# bin/export.sh). Loads the prod env from the supervisord service file and writes
# the export JSON to the given path via the release's `eval` — no running node /
# epmd needed. Don't call this from your laptop; use bin/export.sh.
#
#     ./bin/export_remote.sh <all|in_progress|completed|aborted> <output_path>
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/_build/prod/rel/ownership_ash_chat/bin/ownership_ash_chat"

status="${1:-all}"
output="${2:?output path required}"

case "$status" in
  all)         arg="nil" ;;
  in_progress) arg=":in_progress" ;;
  completed)   arg=":completed" ;;
  aborted)     arg=":aborted" ;;
  *) echo "Unknown status '$status' (use: all|in_progress|completed|aborted)" >&2; exit 1 ;;
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
