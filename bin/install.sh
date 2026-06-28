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

## pre-place the esbuild/tailwind linux binaries.
##
## mix esbuild/tailwind would otherwise download them itself, but Erlang/OTP 28's
## TLS 1.3 stack fails the GitHub middlebox handshake ("hello_retry_middlebox_assert")
## so the in-VM download dies. curl's TLS works fine, so we fetch the binaries to the
## exact paths the mix tasks expect; they then skip their own broken download.
## Versions must match config/config.exs (esbuild + tailwind `version:`).
ESBUILD_VERSION="0.25.4"
TAILWIND_VERSION="4.3.0"
esbuild_bin="_build/esbuild-linux-x64"
tailwind_bin="_build/tailwind-linux-x64-${TAILWIND_VERSION}"

if [ ! -x "$esbuild_bin" ]; then
  curl -fsSL "https://registry.npmjs.org/@esbuild/linux-x64/-/linux-x64-${ESBUILD_VERSION}.tgz" -o /tmp/esbuild.tgz
  tar -xzf /tmp/esbuild.tgz -C /tmp
  cp /tmp/package/bin/esbuild "$esbuild_bin"
  chmod +x "$esbuild_bin"
fi

if [ ! -x "$tailwind_bin" ]; then
  curl -fsSL "https://github.com/tailwindlabs/tailwindcss/releases/download/v${TAILWIND_VERSION}/tailwindcss-linux-x64" -o "$tailwind_bin"
  chmod +x "$tailwind_bin"
fi

## build assets (no assets/package.json in this project — npm is not used)
mix phx.digest.clean
mix assets.deploy
