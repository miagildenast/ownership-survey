# OwnershipAshChat — Haiku Study

Phoenix/Ash application backing a research study in which participants write haikus
(see `AGENTS.md` for the full study concept). The participant walks a randomized sequence
of writing runs at `/study`; entry is normally via the upstream `case_id` link, but a
one-click dev route starts a randomized session locally.

## Setup

- `mix setup` — install deps, create + migrate the database
- `mix phx.server` (or `iex -S mix phx.server`) — start the server
- Visit [`localhost:4000`](http://localhost:4000)

For the production stack, see the [Phoenix deployment guides](https://phoenix.hexdocs.pm/deployment.html).

## LLM backend

The chatbot is config-driven (`OwnershipAshChat.LLM`):

- **prod** — Anthropic / Claude (`ANTHROPIC_API_KEY` required)
- **dev/test** — a local OpenAI-compatible endpoint, by default
  [LM Studio](https://lmstudio.ai/) on `http://localhost:1234/v1`

`:with_ai` (ping-pong) runs call the model, so they need a backend running.
`:without_ai` (solo writing) runs need **no** LLM.

Tunable via `LLM_MODEL`, `LLM_BASE_URL`, `LLM_API_KEY` / `ANTHROPIC_API_KEY`
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
`:with_ai` runs), and once the haiku is complete click **Weiter** to advance. After Run 4
the end card shows the session id. Reloading mid-flow resumes at the current run.

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

## Learn more

- Study concept & data model: `AGENTS.md`
- Phoenix: https://www.phoenixframework.org/ · https://phoenix.hexdocs.pm
- Ash: https://ash-hq.org · https://hexdocs.pm/ash
