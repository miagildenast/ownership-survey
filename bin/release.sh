#!/bin/bash
set -x
set -e

# build the release and run migrations on the remote server

## set environment variables
export MIX_ENV="prod"

## generate release
mix release --overwrite

## load prod secrets/env for the migrate step.
## runtime.exs requires DATABASE_PATH, SECRET_KEY_BASE, TOKEN_SIGNING_SECRET and
## the API key for whichever LLM backend option is active (OPENROUTER_API_KEY or
## OPENAI_API_KEY — see config/runtime.exs) in :prod for *every* release command
## (including `eval`).
## Single source of truth is the deployed supervisord ini (bin/deploy.sh rsyncs it to
## ~/etc/services.d/; the project copy is gitignored and never shipped). We parse its
## `environment=` block (indented KEY="val", lines, comments and trailing commas
## stripped) so there is no separate .env file to keep in sync.
ini="$HOME/etc/services.d/ownership_ash_chat.ini"
if [ -f "$ini" ]; then
  set -a
  # shellcheck disable=SC1090
  . <(awk '
    /^environment=/ { inblock = 1; next }
    inblock && /^[^[:space:]]/ { inblock = 0 }
    inblock {
      sub(/#.*/, "")
      gsub(/^[[:space:]]+/, "")
      sub(/,[[:space:]]*$/, "")
      if (length($0)) print
    }
  ' "$ini")
  set +a
else
  echo "ERROR: supervisord ini not found at $ini — run bin/deploy.sh (it rsyncs it)." >&2
  exit 1
fi

## run database migrations
_build/prod/rel/ownership_ash_chat/bin/migrate
