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

: "${UBERSPACE_USER:?set UBERSPACE_USER (see .envrc.private.example)}"
: "${UBERSPACE_SERVER:?set UBERSPACE_SERVER (see .envrc.private.example)}"

status="${1:-all}"
local_out="${2:-study_export_${status}.json}"

# Path on the server (relative to the login home dir) for the freshly built JSON.
remote_tmp="ownership_ash_chat_export_${status}.json"

# build the JSON on the server
ssh "$UBERSPACE_USER@$UBERSPACE_SERVER" \
  "bash -l -c 'cd ownership_ash_chat && ./bin/export_remote.sh $status ~/$remote_tmp'"

# download it to the requested local path
rsync --archive --compress --human-readable \
      "$UBERSPACE_USER@$UBERSPACE_SERVER:$remote_tmp" "$local_out"

# clean up the server-side temp file
ssh "$UBERSPACE_USER@$UBERSPACE_SERVER" "rm -f ~/$remote_tmp"

echo "Wrote $local_out"
