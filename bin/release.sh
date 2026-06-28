#!/bin/bash
set -x
set -e

# build the release and run migrations on the remote server

## set environment variables
export MIX_ENV="prod"

## generate release
mix release --overwrite

## load prod secrets/env for the migrate step.
## runtime.exs requires DATABASE_URL, SECRET_KEY_BASE and TOKEN_SIGNING_SECRET
## in :prod for *every* release command (including `eval`), so we source them
## here. Copy bin/ownership_ash_chat.env.example to .env.prod on the server.
if [ -f .env.prod ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env.prod
  set +a
fi

## run database migrations
_build/prod/rel/ownership_ash_chat/bin/migrate
