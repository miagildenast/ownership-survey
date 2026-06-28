# OwnershipAshChat — Haiku Study

Phoenix/Ash application backing a research study in which participants write haikus
(see `AGENTS.md` for the full study concept). Most of the app is still domain + persistence;
the first human-facing piece is a **dev harness** that lets you walk a single writing run
end to end in the browser.

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

## Trying the writing flow (dev harness)

The participant entry point (`/start?case_id=…`, randomized runs) is not wired up yet.
To exercise the writing flow today, create a run by hand and open it in the browser. The
harness route is only available with `dev_routes` enabled.

**1. Start the server**

```sh
mix phx.server
```

**2. Create a session + run** (second terminal, IEx)

```sh
iex -S mix
```

```elixir
s = OwnershipAshChat.Study.create_session!(%{
  case_id: "local-6",
  topic_source_order: [:free, :assigned]
})

# without_ai — no LLM needed:
#r = OwnershipAshChat.Study.create_run!(%{
#  run_index: 1,
#  topic_source: :free,
#  ai_mode: :without_ai,
#  session_id: s.id
#})

# with_ai — ping-pong, needs an LLM backend (e.g. LM Studio on localhost:1234):
r = OwnershipAshChat.Study.create_run!(%{
  run_index: 1,
  topic_source: :free,
  ai_mode: :with_ai,
  session_id: s.id
})

r.id
"http://localhost:4000/dev/study/run/#{r.id}"
```

**3. Open the run in the browser** — use the `r.id` printed above:

```
http://localhost:4000/dev/study/run/<RUN_ID>
```

There you can set the topic (for `:free`), add passages (ping-pong with the AI for
`:with_ai`), and record the final haiku.

## Learn more

- Study concept & data model: `AGENTS.md`
- Phoenix: https://www.phoenixframework.org/ · https://phoenix.hexdocs.pm
- Ash: https://ash-hq.org · https://hexdocs.pm/ash
