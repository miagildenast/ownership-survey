#!/bin/bash
set -ex

# setup project on remote server

## set environment variables
export MIX_ENV="prod"

### we need to use uberspace's exqlite installation
### because we cannot compile exqlite on the server
export EXQLITE_USE_SYSTEM=1
export EXQLITE_SYSTEM_CFLAGS="-I/usr/include"
export EXQLITE_SYSTEM_LDFLAGS="-L/lib64/sqlite -lsqlite3"

## get dependencies and compile
mix local.hex --force
mix local.rebar --force
mix deps.get --only prod
mix compile

## NOTE: assets are NOT built here. Tailwind v4 cannot run on uberspace (its native
## @parcel/watcher needs a newer libstdc++ than the host ships). bin/deploy.sh builds
## the assets locally and rsyncs the compiled priv/static; bin/release.sh's `mix release`
## then packages it. So no npm install / assets.deploy / phx.digest on the server.
