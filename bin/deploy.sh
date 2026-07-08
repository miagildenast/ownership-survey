#!/bin/bash
set -euo pipefail

# Deploy ownership_ash_chat to Uberspace via rsync + build-on-server.
#
# Requires UBERSPACE_USER and UBERSPACE_SERVER in the environment
# (see .envrc.private.example).

: "${UBERSPACE_USER:?set UBERSPACE_USER (see .envrc.private.example)}"
: "${UBERSPACE_SERVER:?set UBERSPACE_SERVER (see .envrc.private.example)}"

remote="/home/$UBERSPACE_USER/ownership_ash_chat"

# --skip-assets: skip local asset build, ship whatever's already in priv/static.
skip_assets=false
if [[ "${1:-}" == "--skip-assets" ]]; then
  skip_assets=true
fi

# build assets LOCALLY and ship the compiled priv/static.
#
# Tailwind v4 cannot run on uberspace: both its standalone binary (Bun) and the npm
# CLI (node) load @parcel/watcher, whose native module needs a newer libstdc++
# (GLIBCXX_3.4.20) than uberspace ships. So we compile (to generate the
# phoenix-colocated CSS) and run assets.deploy here, where tailwind works, then rsync
# the result. The server never builds assets.
if [[ "$skip_assets" == true ]]; then
  # guard: the second rsync below uses --delete against remote priv/static. If
  # local priv/static is missing/empty, that rsync would wipe the server's assets
  # instead of skipping them. Fail loudly instead.
  if [[ ! -d "priv/static" ]] || [[ -z "$(ls -A priv/static 2>/dev/null)" ]]; then
    echo "!! --skip-assets given but priv/static is missing or empty locally." >&2
    echo "!! refusing to rsync --delete an empty dir over the server's assets." >&2
    exit 1
  fi
  echo ">> skipping asset build (--skip-assets), shipping existing priv/static"
else
  echo ">> building assets locally (MIX_ENV=prod)"
  MIX_ENV=prod mix compile
  MIX_ENV=prod mix assets.deploy
fi

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
      "$UBERSPACE_USER@$UBERSPACE_SERVER:$remote/"

# ship the locally-built assets. priv/static is gitignored (build artifact), so the
# gitignore-driven sync above skips it — push it explicitly. --delete prunes stale
# digested files on the server.
rsync --archive --compress --progress --partial --human-readable --delete \
      "$(pwd)/priv/static/" \
      "$UBERSPACE_USER@$UBERSPACE_SERVER:$remote/priv/static/"

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
