#!/bin/bash
set -euo pipefail

# Deploy ownership_ash_chat to Uberspace via rsync + build-on-server.
#
# Requires UBERSPACE_USER and UBERSPACE_SERVER in the environment
# (see .envrc.private.example).

: "${UBERSPACE_USER:?set UBERSPACE_USER (see .envrc.private.example)}"
: "${UBERSPACE_SERVER:?set UBERSPACE_SERVER (see .envrc.private.example)}"

# synchronize project files (respect .gitignore, never ship .git)
#
# NOTE: the trailing slash on the source is load-bearing. Without it rsync's
# transfer root is the *parent* dir, so .gitignore's `/`-anchored patterns
# (e.g. `/_build/`, `/deps/`) anchor to the wrong place and the dir-merge
# filter fails to exclude them — shipping ~1.3 GB and OOM-killing rsync. With
# the trailing slash the transfer root is the project dir, anchors resolve
# correctly, and .gitignore stays the single source of truth (only .git is
# excluded explicitly, since git cannot ignore itself).
rsync --archive --compress --progress --partial --human-readable \
      --filter=":- .gitignore" --exclude=".git" "$(pwd)/" \
      "$UBERSPACE_USER@$UBERSPACE_SERVER:/home/$UBERSPACE_USER/ownership_ash_chat/"

# install the supervisord service definition
rsync --archive --compress --progress --partial --human-readable \
      "$(pwd)/bin/ownership_ash_chat.ini" \
      "$UBERSPACE_USER@$UBERSPACE_SERVER:/home/$UBERSPACE_USER/etc/services.d/ownership_ash_chat.ini"

# setup project on remote server.
# NOTE: ssh opens a non-interactive shell, so we use 'bash -l -c' to ensure the
#       login shell is used and the asdf/env setup is loaded correctly.
ssh -t "$UBERSPACE_USER@$UBERSPACE_SERVER" 'bash -l -c "cd ownership_ash_chat && ./bin/install.sh"'
ssh -t "$UBERSPACE_USER@$UBERSPACE_SERVER" 'bash -l -c "cd ownership_ash_chat && ./bin/release.sh"'
ssh -t "$UBERSPACE_USER@$UBERSPACE_SERVER" 'bash -l -c "cd ownership_ash_chat && ./bin/restart_service.sh"'
