#!/bin/bash
set -euo pipefail

# Deploy ownership_ash_chat to Uberspace via rsync + build-on-server.
#
# Requires UBERSPACE_USER and UBERSPACE_SERVER in the environment
# (see .envrc.private.example).

: "${UBERSPACE_USER:?set UBERSPACE_USER (see .envrc.private.example)}"
: "${UBERSPACE_SERVER:?set UBERSPACE_SERVER (see .envrc.private.example)}"

# synchronize project files (respect .gitignore, never ship .git)
rsync --archive --compress --progress --partial --human-readable \
      --filter=":- .gitignore" --exclude=".git" "$(pwd)" \
      "$UBERSPACE_USER@$UBERSPACE_SERVER:/home/$UBERSPACE_USER/"

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
