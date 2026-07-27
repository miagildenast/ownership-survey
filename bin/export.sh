#!/bin/bash
set -euo pipefail

# Export study data from prod, run from the client (like bin/deploy.sh).
#
# Builds the JSON on the server (via bin/export_remote.sh), then rsyncs it down to
# the local path you give. Requires UBERSPACE_USER and UBERSPACE_SERVER in the
# environment (see .envrc.private.example).
#
#     ./bin/export.sh                              # all -> ./study_export_all.json
#     ./bin/export.sh completed                    # completed -> ./study_export_completed.json
#     ./bin/export.sh completed ~/Desktop/x.json   # completed -> given local path
#
#     ./bin/export.sh --session-id <session_id> [local_out]
#     ./bin/export.sh --case-id <case_id> [local_out]
#     ./bin/export.sh --case-number <case_number> [local_out]
#
#     ./bin/export.sh stats [local_out]            # aggregate stats -> ./study_export_stats.json

: "${UBERSPACE_USER:?set UBERSPACE_USER (see .envrc.private.example)}"
: "${UBERSPACE_SERVER:?set UBERSPACE_SERVER (see .envrc.private.example)}"

case "${1:-all}" in
  --session-id)
    id="${2:?--session-id requires a value}"
    remote_args=(--session-id "$id")
    slug="session_${id}"
    local_out="${3:-study_export_${slug}.json}"
    ;;
  --case-id)
    id="${2:?--case-id requires a value}"
    remote_args=(--case-id "$id")
    slug="case_${id}"
    local_out="${3:-study_export_${slug}.json}"
    ;;
  --case-number)
    id="${2:?--case-number requires a value}"
    remote_args=(--case-number "$id")
    slug="casenum_${id}"
    local_out="${3:-study_export_${slug}.json}"
    ;;
  stats|--stats)
    remote_args=(stats)
    slug="stats"
    local_out="${2:-study_export_stats.json}"
    ;;
  *)
    status="${1:-all}"
    remote_args=("$status")
    slug="$status"
    local_out="${2:-study_export_${slug}.json}"
    ;;
esac

# Path on the server (relative to the login home dir) for the freshly built JSON.
remote_tmp="ownership_ash_chat_export_${slug}.json"

# build the JSON on the server
ssh "$UBERSPACE_USER@$UBERSPACE_SERVER" \
  "bash -l -c 'cd ownership_ash_chat && ./bin/export_remote.sh ${remote_args[*]} ~/$remote_tmp'"

# download it to the requested local path
rsync --archive --compress --human-readable \
      "$UBERSPACE_USER@$UBERSPACE_SERVER:$remote_tmp" "$local_out"

# clean up the server-side temp file
ssh "$UBERSPACE_USER@$UBERSPACE_SERVER" "rm -f ~/$remote_tmp"

echo "Wrote $local_out"
