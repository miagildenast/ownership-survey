#!/bin/bash
set -euo pipefail

# Fast content deploy: ship priv/study/config.yml and restart the service so it
# rereads the config — NO rebuild, NO deps, NO migrate.
#
#   1. Validate the YAML locally (schema check) so a broken config never ships.
#   2. rsync ONLY priv/study/config.yml to the server's source tree.
#   3. supervisorctl restart — the release rereads the file at boot (~1s).

: "${UBERSPACE_USER:?set UBERSPACE_USER (see .envrc.private.example)}"
: "${UBERSPACE_SERVER:?set UBERSPACE_SERVER (see .envrc.private.example)}"

remote="/home/$UBERSPACE_USER/ownership_ash_chat"
config="priv/study/config.yml"

if [[ ! -f "$config" ]]; then
  echo "!! $config not found — run from the project root." >&2
  exit 1
fi

# 1. validate locally before shipping. --no-start avoids booting the app/LLM;
#    load!/1 runs the same schema validation used at boot and raises on any error.
echo ">> validating $config locally"
mix run --no-start -e "OwnershipAshChat.Study.Config.load!(\"$config\")"

# 2. ship just the one file.
echo ">> shipping $config"
rsync --archive --compress --human-readable \
      "$(pwd)/$config" \
      "$UBERSPACE_USER@$UBERSPACE_SERVER:$remote/$config"

# 3. restart to reread the config.
echo ">> restarting service"
ssh -t "$UBERSPACE_USER@$UBERSPACE_SERVER" 'bash -l -c "supervisorctl restart ownership_ash_chat"'

echo ">> done — study config live, no rebuild."
