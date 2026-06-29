# OwnershipAshChat — Haiku Study

Phoenix/Ash application backing a research study in which participants write haikus
(see `AGENTS.md` for the full study concept). The participant walks a randomized sequence
of writing runs at `/study`; entry is normally via the upstream `case_id` link, but a
one-click dev route starts a randomized session locally.

## Setup

- `mix setup` — install deps, create + migrate the database
- `mix phx.server` (or `iex -S mix phx.server`) — start the server
- Visit [`localhost:4000`](http://localhost:4000)

For the production stack, see the [Phoenix deployment guides](https://phoenix.hexdocs.pm/deployment.html)
and [Production](#production) below.

## LLM backend

The chatbot is config-driven (`OwnershipAshChat.LLM`):

- **prod** — OpenRouter via OpenAI-compatible endpoint (`OPENROUTER_API_KEY`
  required), default model `openai/gpt-oss-120b:free`
- **dev/test** — a local OpenAI-compatible endpoint, by default
  [LM Studio](https://lmstudio.ai/) on `http://localhost:1234/v1`

`:with_ai` (ping-pong) runs call the model, so they need a backend running.
`:without_ai` (solo writing) runs need **no** LLM.

Tunable via `LLM_MODEL`, `LLM_BASE_URL`, `LLM_API_KEY` / `OPENROUTER_API_KEY`
(see `config/runtime.exs`).

## Local debug session

The fastest way to walk the flow locally — no upstream link, no IEx. The dev routes are
only available with `dev_routes` enabled (the default in `dev`).

**1. Start the server**

```sh
mix phx.server
```

**2. One-click entry**

Open [`localhost:4000/dev/study/new`](http://localhost:4000/dev/study/new). This starts a
fresh session — drawing `topic_source_order` and seeding the four randomized `:writing`
runs — stashes the `session_id` in your session cookie, and drops you on `/study` at Run 1.

Walk each run: set the topic (for `:free` runs), add your lines (ping-pong with the AI for
`:with_ai` runs), and once the haiku is complete submit the questionnaire then click
**Weiter** to advance.

After all four writing runs:

1. A transition card ("Schreibphase abgeschlossen") appears — click **Weiter**.
2. The app picks the best-scoring run (highest Likert average; random tie-break shows a
   flash), draws a modification variant (one word / one line / two lines), and calls the LLM
   to produce the modified haiku.
3. Rate the modification with the questionnaire, then click **Weiter**.
4. The end screen shows the **session UUID** to copy back into the upstream study tool.

Reloading mid-flow resumes at the current run without triggering a second LLM call.

> `:without_ai` runs need no LLM. `:with_ai` runs call the model for line 2, so they need a
> backend running (see [LLM backend](#llm-backend)).

### Single-run harness

To drive one run in isolation by id, use
[`/dev/study/run/:run_id`](http://localhost:4000/dev/study/run). Create a run in IEx
(`iex -S mix`):

```elixir
s = OwnershipAshChat.Study.start_session!(%{case_id: "local-#{System.unique_integer([:positive])}"})
r = hd(OwnershipAshChat.Study.get_session!(s.id, load: [:runs]).runs)
"http://localhost:4000/dev/study/run/#{r.id}"
```

Other dev tooling: LiveDashboard at `/dev/dashboard`, mailbox preview at `/dev/mailbox`.

## Exporting study data

Sessions are stored relationally; JSON is an on-demand export artifact.

### Locally

The `study.export` Mix task (dev only — Mix is not in a release):

```sh
mix study.export <session_id>              # one session, to stdout
mix study.export --all                     # every session
mix study.export --all --status completed  # filter by status
mix study.export --all -o sessions.json    # write to a file
```

Or from IEx (`iex -S mix`), the same code interfaces the task uses:

```elixir
# one session
OwnershipAshChat.Study.export_session!("<session_id>")
|> OwnershipAshChat.Study.Export.to_json!()

# all (optionally filtered)
OwnershipAshChat.Study.list_sessions_for_export!(%{status: :completed})
|> OwnershipAshChat.Study.Export.to_json!()
```

### On prod

Run `bin/export.sh` **from the client** (like `bin/deploy.sh`; needs `UBERSPACE_USER` /
`UBERSPACE_SERVER`). It builds the JSON on the server, then rsyncs it down to the local
path you give:

```sh
./bin/export.sh                              # all -> ./study_export_all.json
./bin/export.sh completed                    # completed -> ./study_export_completed.json
./bin/export.sh completed ~/Desktop/x.json   # completed -> given local path
```

Mix tasks don't ship in a release, so the server side (`bin/export_remote.sh`, invoked
over SSH) loads the prod env from the supervisord service file and calls
`OwnershipAshChat.Release.export/2`. That starts the repo on its own — no dependency on
the running app or Erlang distribution (`remote`/`rpc` need a cookie + epmd, which this
deploy doesn't set up).

## Production

### Hosting on [Uberspace](https://uberspace.de)

Deployment is rsync + build-on-server: the project is synced to the Uberspace
account, deps/assets are built there, a release is cut, migrations run, and the
app is (re)started under [supervisord](https://manual.uberspace.de/daemons-supervisord/).

**One-time setup**

1. Copy `.envrc.private.example` → `.envrc.private` and set `UBERSPACE_USER` /
   `UBERSPACE_SERVER` (then `direnv allow`).
2. Copy `bin/ownership_ash_chat.ini.example` → `bin/ownership_ash_chat.ini` and fill in
   `USER`, `PHX_HOST`, `DATABASE_PATH`, `OPENROUTER_API_KEY`, and the two secrets
   (`mix phx.gen.secret` for `SECRET_KEY_BASE` and `TOKEN_SIGNING_SECRET`). This file is
   gitignored and synced to `~/etc/services.d/` by the deploy script. It is the **single
   source of truth** for prod env: `bin/release.sh` parses its `environment=` block for
   the migration step, so there is no separate `.env` file.

**Deploy**

```bash
./bin/deploy.sh
```

This runs, over SSH: `bin/install.sh` (deps + assets), `bin/release.sh` (`mix release`
then run migrations via the release's `bin/migrate`), and `bin/restart_service.sh`
(`supervisorctl` reread/update/restart).

After the first deploy, [open a web backend on Uberspace](https://manual.uberspace.de/web-backends/#specific-path)
pointing at the `PORT` from `ownership_ash_chat.ini` (default `4001`).

> **Database:** prod uses SQLite (AshSqlite). `DATABASE_PATH` points at the prod `.db`
> file; exqlite links uberspace's system SQLite at build time (see `bin/install.sh`).

### Building a release

`mix release` produces `_build/prod/rel/ownership_ash_chat`, with `bin/server` (starts
the app with `PHX_SERVER=true`) and `bin/migrate` (runs `OwnershipAshChat.Release.migrate`)
from `rel/overlays/bin/`. If you build the release on a different machine than the target,
the build host must match the server's OS/architecture (see the
[Phoenix releases guide](https://hexdocs.pm/phoenix/releases.html)).

## Learn more

- Study concept & data model: `AGENTS.md`
- Phoenix: https://www.phoenixframework.org/ · https://phoenix.hexdocs.pm
- Ash: https://ash-hq.org · https://hexdocs.pm/ash
