This is a web application written using the Phoenix web framework.

## Project guidelines

- **`mix precommit` is the required final gate for every Elixir change.** Run it once after
  all changes are made and fix every issue it reports before considering the work done — never
  treat a change as complete on the strength of piecemeal checks alone. Individual steps
  (`mix compile`, `mix format <file>`, a single `mix test <file>`) **may** be used freely
  _during_ development for debugging or fast feedback, but they do **not** substitute for the
  final `mix precommit` run; the alias exists so nothing (format, warnings-as-errors, tests)
  is skipped at the end.
- Use the already included and available `:req` (`Req`) library for HTTP requests, **avoid** `:httpoison`, `:tesla`, and `:httpc`. Req is included by default and is the preferred HTTP client for Phoenix apps

### Phoenix v1.8 guidelines

- **Always** begin your LiveView templates with `<Layouts.app flash={@flash} ...>` which wraps all inner content
- The `MyAppWeb.Layouts` module is aliased in the `my_app_web.ex` file, so you can use it without needing to alias it again
- Anytime you run into errors with no `current_scope` assign:
  - You failed to follow the Authenticated Routes guidelines, or you failed to pass `current_scope` to `<Layouts.app>`
  - **Always** fix the `current_scope` error by moving your routes to the proper `live_session` and ensure you pass `current_scope` as needed
- Phoenix v1.8 moved the `<.flash_group>` component to the `Layouts` module. You are **forbidden** from calling `<.flash_group>` outside of the `layouts.ex` module
- Out of the box, `core_components.ex` imports an `<.icon name="hero-x-mark" class="w-5 h-5"/>` component for hero icons. **Always** use the `<.icon>` component for icons, **never** use `Heroicons` modules or similar
- **Always** use the imported `<.input>` component for form inputs from `core_components.ex` when available. `<.input>` is imported and using it will save steps and prevent errors
- If you override the default input classes (`<.input class="myclass px-2 py-1 rounded-lg">)`) class with your own values, no default classes are inherited, so your
  custom classes must fully style the input

### JS and CSS guidelines

- **Use Tailwind CSS classes and custom CSS rules** to create polished, responsive, and visually stunning interfaces.
- Tailwindcss v4 **no longer needs a tailwind.config.js** and uses a new import syntax in `app.css`:

      @import "tailwindcss" source(none);
      @source "../css";
      @source "../js";
      @source "../../lib/my_app_web";

- **Always use and maintain this import syntax** in the app.css file for projects generated with `phx.new`
- **Never** use `@apply` when writing raw css
- **Always** manually write your own tailwind-based components instead of using daisyUI for a unique, world-class design
- Out of the box **only the app.js and app.css bundles are supported**
  - You cannot reference an external vendor'd script `src` or link `href` in the layouts
  - You must import the vendor deps into app.js and app.css to use them
  - **Never write inline <script>custom js</script> tags within templates**

### UI/UX & design guidelines

- Aim for polished, responsive, accessible interfaces: clean typography and spacing, subtle
  micro-interactions (hover effects, smooth transitions), and considered loading states.

# Project Description: Haiku Study

> This file describes the conceptual idea behind the project so it can serve as a
> reference for implementation and decisions later. It is intentionally kept high-level;
> open questions are collected at the end.

## Overview

The project is a tool for a **research study** in which participants (subjects)
**write haikus**. It investigates the effect of two factors on the writing experience and
the result:

1. **Topic prompt** – with a given topic vs. without a topic (the participant's first
   line sets the topic implicitly)
2. **AI assistance** – with AI (ping-pong mode) vs. without AI (writing alone)

After each run, participants rate their experience/result on a **Likert scale**
(questionnaire).

## Study Design

### Two crossed factors

The study has two crossed binary factors → **4 writing runs** per participant, plus a
fifth modification run.

- **`topic_source`** (the "condition") — `:assigned` (the fixed topic **"Jahreszeiten"**
  is shown; developer-configurable via `config :ownership_ash_chat, :study_assigned_topic`)
  | `:free` (no topic step — the participant's first haiku line sets the topic implicitly;
  `run.topic` stays empty)
- **`ai_mode`** (with/without AI) — `:with_ai` (ping-pong with chatbot) | `:without_ai`
  (participant writes alone)

### Nested randomization (block structure)

`topic_source` is the **outer block**, `ai_mode` is the **inner factor**. Both `ai_mode`
values of one `topic_source` are completed back-to-back before switching `topic_source`:

1. The two **`topic_source`** values (`:assigned`, `:free`) are assigned in **random
   order**.
2. On entering a `topic_source`, one of the two **`ai_mode`** values (`:with_ai`,
   `:without_ai`) is chosen **at random**.
3. When that run completes, the **other `ai_mode`** of the **same `topic_source`** is run.
4. **Only then** the participant moves to the **next `topic_source`** (again random
   `ai_mode` order within).

This yields 4 runs whose presented order is one of 8 valid sequences (2 `topic_source`
orders × 2 `ai_mode` orders per `topic_source`).

Each run ends with a **Likert survey**.

### Ping-pong mode (with AI)

Alternating writing, one haiku line per turn (3 lines total, 5-7-5). Who starts depends
on `topic_source`:

- **`:free && :with_ai`** — `[user, AI, user]`. No topic exists; the user's first line
  sets it implicitly.
  1. user writes line 1
  2. AI generates line 2 from line 1 (**7 syllables**)
  3. user writes line 3
- **`:assigned && :with_ai`** — `[AI, user, AI]`. The assigned topic feeds the AI's
  opening prompt.
  1. AI generates line 1 from the topic (**5 syllables**) — shown before any input
  2. user writes line 2
  3. AI generates line 3 from lines 1+2 (**5 syllables**)

A run ends (auto-completes, `final_haiku` assembled) once it holds 3 lines. AI lines are
syllable-validated with a retry loop (`Study.PingPong` + `Study.Syllables`); user input
is **never** syllable-validated.

### Fifth run (modification)

An additional, **fifth run** builds on the results:

1. The **"best" run** of the four previous ones is taken as the starting point.
   - **Determination**: highest **average** across the run's Likert items.
   - All Likert questions are **positively coded** (higher = better), so they can be
     averaged directly without reverse-scoring.
   - **Tie-break**: on equal averages the winner is chosen **at random**. Both the
     best-run and tie-break logic live in the domain (`Run.Changes.CreateModification`
     via `Randomization.best_run/1`), not the LiveView.
2. **Only the participant's own first line is modified** — never an AI-written line
   (`Transcript.first_user_index/1`): `:free && :with_ai` → line 1,
   `:assigned && :with_ai` → line 2, `:without_ai` → line 1. The chatbot is asked for a
   new version of just that one line, which is **spliced back in** so every other line
   stays byte-identical.
3. Two **variants**, chosen at random:
   - **5a** – only **one word** in the target line is changed
   - **5b** – the whole **target line** is replaced
4. Afterwards the **Likert scale is asked again** (rating of the modified version).

## Access & Identification

- **No classic login** (no username/password).
- Participants enter the application via a link carrying a `case_id`:
  ```
  /start?case_id=%caseToken%
  ```
  The `%caseToken%` placeholder is filled by the **upstream study tool** (e.g. a
  survey/panel software) into the `case_id` query param. The value identifies the case.
- The **`case_id`** is the value passed in the link; it maps our session to the external
  tool. (Lean first pass: the value is treated as the `case_id` verbatim — no
  signature/expiry yet; see [Open questions](#open-questions).)
- **Re-entry resumes.** The same `case_id` upserts on the `unique_case_id` identity, so a
  reload or back-navigation returns the participant to their existing session rather than
  starting a new one.

### Return to the originating tool

- At the end of the **last run**, a **UUID** is displayed.
- The participant takes this UUID back into the originating tool so the datasets can be
  **matched later** (mapping between our dataset and the external tool).

## Participant flow (high level)

1. Entry via `/start?case_id=…`.
2. Four runs in nested-block order (both `ai_mode` values of one `topic_source`, then the
   next `topic_source` — see Study Design):
   - topic display for `:assigned` (fixed "Jahreszeiten"); no topic step for `:free`,
   - writing phase (alone or ping-pong with chatbot, depending on `ai_mode`; see
     Ping-pong mode for who starts),
   - Likert survey.
3. Fifth run: modification on the best haiku — the participant's own first line is
   rewritten (random variant 5a/5b) + Likert.
4. Display of the **UUID** (run/session ID) to return to the originating tool.

## Data model

Persisted **relationally via AshSqlite** (the app uses SQLite + AshSqlite):
a **`session`** resource `has_many` **`run`** resources. JSON is **not** the storage format
— it is only an **export artifact**, generated on demand from a read action (load `session`
with its `runs` and serialize, e.g. via `Jason`). Field names below are the domain
attribute names (snake_case); exported JSON keys mirror them.

### `session` (one per participant / `case_id`)

- `case_id` – the value from the entry link; mapping to the external tool
- `case_number` – an additional per-session identifier (`unique_case_number` identity); an
  alternate lookup key, usable as an export selector alongside `case_id`
- `session_id` (UUID) – the id shown at the end for later matching
- `topic_source_order` – randomized order of the two `topic_source` blocks, e.g.
  `[:free, :assigned]`
- `runs` – the run records (4 writing + 1 modification)
- `status` – `:in_progress | :completed | :aborted`
- `started_at` / `completed_at`
- `metadata` – tool/app version, LLM model used

### `run` (one writing+survey unit = one cell)

- `run_index` – presented order, `1..4` (modification run separate, see below)
- `kind` – `:writing | :modification`
- `topic_source` – `:assigned | :free`
- `ai_mode` – `:with_ai | :without_ai`
- `topic` – the assigned topic text ("Jahreszeiten"); empty for `:free` runs (the topic
  is implicit in the first line)
- `transcript` – the messages (user + AI), in order
- `final_haiku` – the finished haiku (separate from the transcript, for easy analysis)
- `likert` – questionnaire answers (all items positively coded)
- `started_at` / `completed_at`

### Modification run (the fifth, `kind: :modification`)

- `variant` – `:a` (one word) | `:b` (one line), assigned at random
- `source_run_index` – which writing run was the "best" (highest Likert average) and used
  as the basis
- `modified_line_index` – 0-based index of the (participant-written) line that was
  rewritten
- `original_haiku` / `modified_haiku` – before/after the chatbot's change (differ only in
  the target line)
- `transcript` – the three lines of the modified haiku; the rewritten line carries the
  role **`ai_enhanced`**, the others keep their source roles (`user`/`ai`)
- `likert` – questionnaire answers on the modified version

## Technical context (current state)

- Phoenix/Ash + AshSqlite application. It was scaffolded from the `ash_ai.gen.chat` starter,
  but the generated `Chat` and `Accounts` domains have since been dropped; the study stores
  each run's transcript embedded on the `run` resource rather than as chat-message rows.
- The LLM is config-driven (`OwnershipAshChat.LLM`, `lib/ownership_ash_chat/llm.ex`): prod
  via a configurable OpenAI-compatible backend — Option A OpenRouter or Option B the real
  OpenAI API — and dev/test via a local OpenAI-compatible endpoint (LM Studio). Config lives
  in `config/runtime.exs` (env-branched), tunable via `LLM_MODEL`, `LLM_BASE_URL`, and the
  active backend's API key (`OPENROUTER_API_KEY` for Option A / `OPENAI_API_KEY` for Option
  B in prod; `LLM_API_KEY` for the local dev/test endpoint).
- Ping-pong (`:with_ai`) AI turns are generated by `OwnershipAshChat.Study.PingPong` from a
  run's current transcript, using the central LLM config and `ReqLLM`. No tools /
  function-calling are used — the local dev model (Gemma) isn't reliable at it and the study
  doesn't need them — so it's a plain text flow.
- The participant flow is a chat-style LiveView (`OwnershipAshChatWeb.StudySessionLive`,
  routed at `/study`; `case_id` entry instead of auth) running the per-condition phases,
  ping-pong, and post-run questionnaires. See the README for the entry and dev-harness routes.

### Study configuration (`priv/study/config.yml`)

The study is driven by a single YAML file, `priv/study/config.yml`, read through
`OwnershipAshChat.Study.Config`. It is the source of truth for the per-condition run
definitions, the **5-point Likert scale** (labels + items, all positively coded), all
participant-facing copy — which is **German** — surfaced via `OwnershipAshChatWeb.StudyTexts`
(it maps a run's `topic_source`/`ai_mode`/position to the configured text), and the LLM
`system_preamble` (`OwnershipAshChat.LLM.system_preamble/0` delegates to
`Study.Config.system_preamble/0`). Change study copy or questionnaire items by editing the
YAML, not the code. The file location is overridable via
`config :ownership_ash_chat, :study_config_path`.

### Notifications

A pluggable notification layer (`OwnershipAshChat.Notifications`) pings an external channel
on key lifecycle/study events. It's an `ex_knigge` (`Knigge`) behaviour facade (`deliver/1`
callback) with `delegate_at_runtime?: true`, so a release picks its backend from runtime
config. Backends: `Notifications.Telegram` (Telegram Bot API via `Req`) and
`Notifications.Disabled` (the no-op default when `NOTIFICATION_PROVIDER` is unset). The
backend is selected in `config/runtime.exs` (guarded `if config_env() != :test`) from
`NOTIFICATION_PROVIDER` (`TELEGRAM` → Telegram); credentials come from
`NOTIFICATION_PROVIDER_TELEGRAM_BOT_TOKEN` / `NOTIFICATION_PROVIDER_TELEGRAM_CHAT_ID`.

Call sites go through `Notifications.Events` (English message formatters, fire-and-forget
via `Task.start` — except `app_stopping`, which is synchronous), never `deliver/1` directly.
Events and their hooks:

- **app started / app stopping** — `Notifications.Lifecycle`, a GenServer registered last in
  `application.ex` that traps exits.
- **session started** — a hook in `Study.Session.Changes.SeedRuns` (fresh-insert branch
  only).
- **session completed** — an Ash notifier `Study.Session.Notifiers.SessionEvents` on the
  `:complete` action.
- **AI generation failed** — the ping-pong LLM call's `{:error, _}` branch (`Study.PingPong`).

It's **best-effort**: a failed/misconfigured send is logged and swallowed, never blocking the
study flow. Tests swap in a forwarding `Notifications.TestBackend` (via `config/test.exs`)
that relays to a registered pid; see `test/ownership_ash_chat/notifications_test.exs`. The
operator-facing setup (Telegram token/chat id, enabling on the host) lives in the README's
Notifications section (under `## Operations`) — cross-reference it rather than duplicating.

### Study data export (all entry points)

Export is a **layered stack** — the JSON is always built by
`OwnershipAshChat.Study.Export` from the `:export` / `:export_all` read actions, but it is
reached through several entry points. **When you add or change an export selector — the
`case_number` lookup key was added in exactly this way, on top of the original `session_id`
and `case_id` — you MUST update every layer below; a code-only change leaves the shell
wrappers broken.** Trace the call path, not just the Elixir symbol; the shell selectors
(`--case-id`, `--case-number`, …) are plain args, invisible to a code search.

- **Domain** — `lib/ownership_ash_chat/study.ex`: `define :export_session_by_<key>` code
  interfaces (`get_by:` needs a matching identity on the resource) + `list_sessions_for_export`.
- **Serialization** — `lib/ownership_ash_chat/study/export.ex`: `session_to_map/1` (mirror
  every persisted attribute into the exported map) + `to_json!/1`.
- **Mix task (local/dev)** — `lib/mix/tasks/study.export.ex`: `@switches`, the `build_json/1`
  dispatch, and the `usage_error/0` text.
- **Release helper (prod, no Mix)** — `lib/ownership_ash_chat/release.ex`: `export/2`'s
  `export_json/1` selector clauses (`{:session_id, _}`, `{:case_id, _}`, …).
- **Shell wrappers** — how export is actually invoked against prod (Uberspace):
  - `bin/export.sh` — client: parses the selector, SSHes to the server, rsyncs the JSON down.
  - `bin/export_remote.sh` — server: maps the selector to the `Release.export/2` arg tuple and
    runs the release `eval`. **This is the script that errors on an unknown selector.**

A new selector therefore touches: resource identity → domain define → export map (if a new
field) → mix task → release helper → **both** shell scripts. Deploying it to prod also
requires a `./bin/deploy.sh` (rebuilds the release + runs `bin/migrate`).

### Repo conventions

- **`AGENTS.md` is the single source of truth**; `CLAUDE.md` is a symlink to it. Edit
  `AGENTS.md`, never `CLAUDE.md` directly.
- `mix usage_rules.sync` targets `AGENTS.md` (see `mix.exs`) and only rewrites the
  `<!-- usage-rules-* -->` managed block — content above it (this description) is safe.

### Guard: consult the Ash skill references BEFORE writing Ash code

**Mandatory.** Before writing or editing any Ash resource, action, domain, migration,
or **test**, you MUST first invoke the `ash-framework` skill and read the relevant
`references/*.md` file(s) — do not work from memory. The references override your
assumptions. Map the task to its reference and read it first:

- resources/actions → `references/actions.md`, `references/code_structure.md`
- domains & calling into resources → `references/code_interfaces.md`
- relationships / managing related data → `references/relationships.md`
- migrations & data layer → `references/migrations.md`, `references/ash_postgres.md`
- **tests** → `references/testing.md` (use `Ash.Generator` + `Ash.Test`, test through
  the code interface, prefer raising functions; see `test/support/study_generators.ex`)
- generating code → `references/generating_code.md` (prefer `mix ash.gen.*`)

When unsure which reference applies, `mix usage_rules.search_docs "<term>" -p ash ...`.
State in your reply which reference(s) you consulted. If you skipped this and wrote Ash
code from memory, stop and redo it against the references.

## Open questions

Most of the original design questions are now resolved and folded into the sections above
(topic prompt, ping-pong, the 5-point German Likert questionnaire, relational persistence,
and re-entry/resume). What remains genuinely open:

- **`case_id` security**: the lean first pass treats the link value as the `case_id`
  verbatim and rejects only blank/missing (redirect to `/`). Open: signature/expiry/
  single-use validation.

<!-- usage-rules-start -->
<!-- usage_rules-start -->
## usage_rules usage
_A config-driven dev tool for Elixir projects to manage AGENTS.md files and agent skills from dependencies_

## Using Usage Rules

Many packages have usage rules, which you should *thoroughly* consult before taking any
action. These usage rules contain guidelines and rules *directly from the package authors*.
They are your best source of knowledge for making decisions.

## Modules & functions in the current app and dependencies

When looking for docs for modules & functions that are dependencies of the current project,
or for Elixir itself, use `mix usage_rules.docs`

```
# Search a whole module
mix usage_rules.docs Enum

# Search a specific function
mix usage_rules.docs Enum.zip

# Search a specific function & arity
mix usage_rules.docs Enum.zip/1
```


## Searching Documentation

You should also consult the documentation of any tools you are using, early and often. The best 
way to accomplish this is to use the `usage_rules.search_docs` mix task. Once you have
found what you are looking for, use the links in the search results to get more detail. For example:

```
# Search docs for all packages in the current application, including Elixir
mix usage_rules.search_docs Enum.zip

# Search docs for specific packages
mix usage_rules.search_docs Req.get -p req

# Search docs for multi-word queries
mix usage_rules.search_docs "making requests" -p req

# Search only in titles (useful for finding specific functions/modules)
mix usage_rules.search_docs "Enum.zip" --query-by title
```


<!-- usage_rules-end -->
<!-- usage_rules:elixir-start -->
## usage_rules:elixir usage
# Elixir Core Usage Rules

## Pattern Matching
- Use pattern matching over conditional logic when possible
- Prefer to match on function heads instead of using `if`/`else` or `case` in function bodies
- `%{}` matches ANY map, not just empty maps. Use `map_size(map) == 0` guard to check for truly empty maps

## Error Handling
- Use `{:ok, result}` and `{:error, reason}` tuples for operations that can fail
- Avoid raising exceptions for control flow
- Use `with` for chaining operations that return `{:ok, _}` or `{:error, _}`

## Common Mistakes to Avoid
- Elixir has no `return` statement, nor early returns. The last expression in a block is always returned.
- Don't use `Enum` functions on large collections when `Stream` is more appropriate
- Avoid nested `case` statements - refactor to a single `case`, `with` or separate functions
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Lists and enumerables cannot be indexed with brackets. Use pattern matching or `Enum` functions
- Prefer `Enum` functions like `Enum.reduce` over recursion
- When recursion is necessary, prefer to use pattern matching in function heads for base case detection
- Using the process dictionary is typically a sign of unidiomatic code
- Only use macros if explicitly requested
- There are many useful standard library functions, prefer to use them where possible

## Function Design
- Use guard clauses: `when is_binary(name) and byte_size(name) > 0`
- Prefer multiple function clauses over complex conditional logic
- Name functions descriptively: `calculate_total_price/2` not `calc/2`
- Predicate function names should not start with `is` and should end in a question mark.
- Names like `is_thing` should be reserved for guards

## Data Structures
- Use structs over maps when the shape is known: `defstruct [:name, :age]`
- Prefer keyword lists for options: `[timeout: 5000, retries: 3]`
- Use maps for dynamic key-value data
- Prefer to prepend to lists `[new | list]` not `list ++ [new]`

## Mix Tasks

- Use `mix help` to list available mix tasks
- Use `mix help task_name` to get docs for an individual task
- Read the docs and options fully before using tasks

## Testing
- Run tests in a specific file with `mix test test/my_test.exs` and a specific test with the line number `mix test path/to/test.exs:123`
- Limit the number of failed tests with `mix test --max-failures n`
- Use `@tag` to tag specific tests, and `mix test --only tag` to run only those tests
- Use `assert_raise` for testing expected exceptions: `assert_raise ArgumentError, fn -> invalid_function() end`
- Use `mix help test` to for full documentation on running tests

## Debugging

- Use `dbg/1` to print values while debugging. This will display the formatted value and other relevant information in the console.

<!-- usage_rules:elixir-end -->
<!-- usage_rules:otp-start -->
## usage_rules:otp usage
# OTP Usage Rules

## GenServer Best Practices
- Keep state simple and serializable
- Handle all expected messages explicitly
- Use `handle_continue/2` for post-init work
- Implement proper cleanup in `terminate/2` when necessary

## Process Communication
- Use `GenServer.call/3` for synchronous requests expecting replies
- Use `GenServer.cast/2` for fire-and-forget messages.
- When in doubt, use `call` over `cast`, to ensure back-pressure
- Set appropriate timeouts for `call/3` operations

## Fault Tolerance
- Set up processes such that they can handle crashing and being restarted by supervisors
- Use `:max_restarts` and `:max_seconds` to prevent restart loops

## Task and Async
- Use `Task.Supervisor` for better fault tolerance
- Handle task failures with `Task.yield/2` or `Task.shutdown/2`
- Set appropriate task timeouts
- Use `Task.async_stream/3` for concurrent enumeration with back-pressure

<!-- usage_rules:otp-end -->
<!-- req_llm-start -->
## req_llm usage
_req_llm_

# ReqLLM Usage Rules

ReqLLM provides two API layers for AI interactions: high-level convenience functions and low-level Req plugin access.

## High-Level API

### Text Generation

```elixir
# Simple text generation
ReqLLM.generate_text!("anthropic:claude-haiku-4-5", "Hello world")
#=> "Hello! How can I assist you today?"

# With full response metadata
{:ok, response} = ReqLLM.generate_text("openai:gpt-4", "Hello", temperature: 0.7)
response.usage
#=> %{
#     input_tokens: 8,
#     output_tokens: 12,
#     total_tokens: 20,
#     input_cost: 0.00024,
#     output_cost: 0.00036,
#     total_cost: 0.0006,
#     cost: %{tokens: 0.0006, tools: 0.0, images: 0.0, total: 0.0006}
#   }
```

### Streaming

```elixir
# New API returns StreamResponse struct
{:ok, response} = ReqLLM.stream_text("anthropic:claude-haiku-4-5", "Write a story")
response.stream
|> Stream.each(&IO.write(&1.text))
|> Stream.run()

# Note: stream_text! is deprecated, use stream_text/3 instead
```

### Structured Objects

```elixir
schema = [name: [type: :string, required: true], age: [type: :pos_integer]]
person = ReqLLM.generate_object!("openai:gpt-4", "Generate a person", schema)
#=> %{name: "John Doe", age: 30}
```

### Tools

```elixir
weather_tool = ReqLLM.tool(
  name: "get_weather",
  description: "Get current weather for a location",
  parameter_schema: [location: [type: :string, required: true]],
  callback: {WeatherAPI, :fetch_weather}
)

ReqLLM.generate_text("openai:gpt-4", "What's the weather in Paris?", tools: [weather_tool])
```

### Context & Messages

```elixir
context = ReqLLM.Context.new([
  ReqLLM.Context.system("You are a helpful coding assistant"),
  ReqLLM.Context.user("Explain recursion in Elixir")
])

{:ok, response} = ReqLLM.generate_text("anthropic:claude-haiku-4-5", context)
```

### Model Specifications

```elixir
# String format
ReqLLM.generate_text("anthropic:claude-haiku-4-5", "Hello")

# Tuple format with options
ReqLLM.generate_text({:anthropic, "claude-3-sonnet-20240229", temperature: 0.7}, "Hello")

# Model struct
model = %ReqLLM.Model{provider: :anthropic, model: "claude-3-sonnet-20240229", max_tokens: 100}
ReqLLM.generate_text(model, "Hello")
```

### Key Management

```elixir
# Keys auto-loaded from .env files via dotenvy at startup
# ANTHROPIC_API_KEY=sk-ant-...
# OPENAI_API_KEY=sk-...

# Optional: Store in application config
ReqLLM.put_key(:anthropic_api_key, "sk-ant-...")
ReqLLM.get_key(:openai_api_key)

# Per-request override
ReqLLM.generate_text("openai:gpt-4", "Hello", api_key: "sk-...")
```

## Low-Level API

### Non-Streaming Requests

Direct Req plugin access for custom HTTP control:

```elixir
# Canonical implementation from ReqLLM.Generation.generate_text/3
with {:ok, model} <- ReqLLM.Model.from("anthropic:claude-haiku-4-5"),
     {:ok, provider_module} <- ReqLLM.provider(model.provider),
     {:ok, request} <- provider_module.prepare_request(:chat, model, "Hello!", temperature: 0.7),
     {:ok, %Req.Response{body: response}} <- Req.request(request) do
  {:ok, response}
end

# Custom headers and middleware
{:ok, model} = ReqLLM.Model.from("anthropic:claude-haiku-4-5")
{:ok, provider_module} = ReqLLM.provider(model.provider)
{:ok, request} = provider_module.prepare_request(:chat, model, "Hello!")

custom_request = 
  request
  |> Req.Request.put_header("x-request-id", "my-id")
  |> Req.Request.put_header("x-source", "my-app")

{:ok, response} = Req.request(custom_request)
```

Native ReqLLM telemetry still applies to this low-level Req path, so `provider_module.prepare_request/4` plus `Req.request/1` participates in `[:req_llm, :request, ...]`, `[:req_llm, :reasoning, ...]`, and `[:req_llm, :token_usage]`.

### Streaming Requests

**IMPORTANT**: Streaming uses Finch, not Req. The `prepare_request/4` and `attach/3` callbacks do NOT work for streaming operations.

If you need observability across both sync and streaming requests, attach to ReqLLM's native telemetry events instead of relying on Req middleware alone.

For custom streaming, use the provider's `attach_stream/4` callback or use `ReqLLM.Streaming.start_stream/4`:

```elixir
# High-level streaming API (recommended)
{:ok, response} = ReqLLM.stream_text("anthropic:claude-haiku-4-5", "Hello")
response.stream |> Stream.each(&IO.write(&1.text)) |> Stream.run()

# Low-level streaming (for advanced use cases)
{:ok, model} = ReqLLM.Model.from("anthropic:claude-haiku-4-5")
{:ok, provider_module} = ReqLLM.provider(model.provider)
context = ReqLLM.Context.new("Hello!")

{:ok, stream_response} = ReqLLM.Streaming.start_stream(
  provider_module,
  model,
  context,
  timeout: 60_000
)

stream_response.stream
|> Stream.each(&IO.write(&1.text))
|> Stream.run()
```

## Error Handling

```elixir
case ReqLLM.generate_text("anthropic:claude-haiku-4-5", "Hello") do
  {:ok, response} -> response.text
  {:error, %ReqLLM.Error.API.RateLimit{retry_after: seconds}} -> 
    :timer.sleep(seconds * 1000)
  {:error, %ReqLLM.Error.API.Authentication{}} -> 
    {:error, :auth_failed}
  {:error, error} -> 
    {:error, :unknown}
end
```

## Essential Options

- `:temperature` - Randomness (0.0-2.0)
- `:max_tokens` - Response length limit
- `:tools` - Function calling definitions
- `:system_prompt` - System message
- `:provider_options` - Provider-specific parameters
- `:api_key` - Override stored key

<!-- req_llm-end -->
<!-- ex_check_ng-start -->
## ex_check_ng usage
_ex_check_ng_

# ex_check usage rules

ex_check provides the `mix check` task: it runs all of a project's code analysis &
testing tools (compiler, formatter, credo, dialyzer, tests, security scanners, ...) in
parallel with one command, and reports every failure in a single run.

## Running

```
mix check
```

Runs every detected tool. Tools whose package or required files are absent are skipped
automatically — you do not need to configure them. Exit status is non-zero if any tool
fails.

For machine-readable output (preferred when an agent parses results):

```
mix check --format agent              # JSON status header + raw failure blocks
mix check --format json --output check.json
```

## Useful flags

- `--only NAME` / `-o NAME` — run only the named tool(s); repeatable. e.g. `mix check -o credo -o ex_unit`
- `--except NAME` / `-x NAME` — skip the named tool(s); repeatable.
- `--fix` / `-f` — auto-fix what can be fixed (e.g. `mix format`, unlock unused deps).
- `--retry` / `-r` — run only tools that failed in the previous run.
- `--no-parallel` — run tools sequentially.
- `--config PATH` / `-c PATH` — use a specific config file.
- `--format pretty|agent|json` — output format (default `pretty`).
- `--output PATH` — write the report to a file (only with `--format agent` or `json`).

Combine `--fix --retry` to fix only the tools that just failed.

## Configuration: `.check.exs`

Generate a commented starter config:

```
mix check.gen.config
```

`.check.exs` returns a keyword list. Root keys:

- `:tools` — list of tool tuples (overrides/extends the curated set).
- `:fix` — `true` to always run fix mode (default `false`).
- `:parallel` — `false` to disable parallelism (default `true`).
- `:retry` — `false` to disable auto-retry (default: on when a manifest exists).
- `:skipped` — `false` to hide skipped tools in the summary.

Tool tuple forms:

```elixir
{:credo, false}                              # disable a curated tool
{:credo, "mix credo --strict"}               # override the command
{:my_task, "mix my_task"}                    # add a custom mix task
{:my_tool, ["my_tool", "arg with spaces"]}   # add an arbitrary command
{:npm_test, command: "npm test", cd: "assets", env: %{"CI" => "true"}}
```

Example `.check.exs`:

```elixir
[
  tools: [
    {:dialyzer, false},
    {:credo, "mix credo --strict"},
    {:my_audit, "mix my_audit"}
  ]
]
```

Local-only overrides go in `~/.check.exs` (e.g. `[fix: true]`). Umbrella projects run
tools recursively per child app by default; tune via each tool's `:umbrella` option.

## Curated tools

`mix check` runs these when detected:

- `compiler` — `mix compile --warnings-as-errors`
- `formatter` — `mix format --check-formatted` (fix: `mix format`)
- `unused_deps` — `mix deps.unlock --check-unused` (fix: `--unused`)
- `credo` — `mix credo`
- `dialyzer` — `mix dialyzer` (needs `:dialyxir`)
- `doctor` — `mix doctor` (needs `:doctor`)
- `ex_doc` — `mix docs` (needs `:ex_doc`)
- `sobelow` — `mix sobelow --exit` (needs `:sobelow`)
- `mix_audit` — `mix deps.audit` (needs `:mix_audit`)
- `gettext` — `mix gettext.extract --check-up-to-date` (needs `:gettext`)
- `ex_unit` — `mix test` (retry: `mix test --failed`)
- `npm_test` — `npm test` in `assets/` (needs `package.json`)

## Agent guidance

- Run `mix check` before considering an Elixir change complete — it surfaces compile
  warnings, format drift, credo/dialyzer/test failures in one pass.
- Prefer `mix check --format agent` for parseable output.
- Use `mix check --fix` to resolve formatting and unused-dep issues automatically.
- Do not add tools that aren't installed; ex_check auto-skips missing ones.
- To narrow a slow run while iterating, use `-o`/`--only`.

<!-- ex_check_ng-end -->
<!-- ash-start -->
## ash usage
_A declarative, extensible framework for building Elixir applications._

# Rules for working with Ash

## Understanding Ash

Ash is an opinionated, composable framework for building applications in Elixir. It provides a declarative approach to modeling your domain with resources at the center. Read documentation  *before* attempting to use its features. Do not assume that you have prior knowledge of the framework or its conventions.


<!-- ash-end -->
<!-- ash:actions-start -->
## ash:actions usage
# Actions

- Create specific, well-named actions rather than generic ones
- Put all business logic inside action definitions
- Use hooks like `Ash.Changeset.after_action/2`, `Ash.Changeset.before_action/2` to add additional logic
  inside the same transaction.
- Use hooks like `Ash.Changeset.after_transaction/2`, `Ash.Changeset.before_transaction/2` to add additional logic
  outside the transaction.
- Use action arguments for inputs that need validation
- Use preparations to modify queries before execution
- Preparations support `where` clauses for conditional execution
- Use `only_when_valid?` to skip preparations when the query is invalid
- Use changes to modify changesets before execution
- Use validations to validate changesets before execution
- Prefer domain code interfaces to call actions instead of directly building queries/changesets and calling functions in the `Ash` module
- A resource could be *only generic actions*. This can be useful when you are using a resource only to model behavior.
- Instead of defining functions in the domain, you should be defining actions and exposing them through code interface calls in the domain. Use standard actions when they fit what you're doing and generic actions when you need arbitrary functionality.

## Error Handling

Functions to call actions, like `Ash.create` and code interfaces like `MyApp.Accounts.register_user` all return ok/error tuples. All have `!` variations, like `Ash.create!` and `MyApp.Accounts.register_user!`. Use the `!` variations when you want to "let it crash", like if looking something up that should definitely exist, or calling an action that should always succeed. Always prefer the raising `!` variation over something like `{:ok, user} = MyApp.Accounts.register_user(...)`.

All Ash code returns errors in the form of `{:error, error_class}`. Ash categorizes errors into four main classes:

1. **Forbidden** (`Ash.Error.Forbidden`) - Occurs when a user attempts an action they don't have permission to perform
2. **Invalid** (`Ash.Error.Invalid`) - Occurs when input data doesn't meet validation requirements
3. **Framework** (`Ash.Error.Framework`) - Occurs when there's an issue with how Ash is being used
4. **Unknown** (`Ash.Error.Unknown`) - Occurs for unexpected errors that don't fit the other categories

These error classes help you catch and handle errors at an appropriate level of granularity. An error class will always be the "worst" (highest in the above list) error class from above. Each error class can contain multiple underlying errors, accessible via the `errors` field on the exception.

## Using Validations

Validations ensure that data meets your business requirements before it gets processed by an action. Unlike changes, validations cannot modify the changeset - they can only validate it or add errors.

Validations work on both changesets and queries. Built-in validations that support queries include:
- `action_is`, `argument_does_not_equal`, `argument_equals`, `argument_in`
- `byte_size`, `compare`, `confirm`, `match`, `negate`, `one_of`, `present`, `string_length`
- Custom validations that implement the `supports/1` callback

Common validation patterns:

```elixir
# Built-in validations with custom messages
validate compare(:age, greater_than_or_equal_to: 18) do
  message "You must be at least 18 years old"
end
validate match(:email, "@")
validate one_of(:status, [:active, :inactive, :pending])

# Conditional validations with where clauses
validate present(:phone_number) do
  where present(:contact_method) and eq(:contact_method, "phone")
end

# only_when_valid? - skip validation if prior validations failed
validate expensive_validation() do
  only_when_valid? true
end

# Action-specific vs global validations
actions do
  create :sign_up do
    validate present([:email, :password])  # Only for this action
  end
  
  read :search do
    argument :email, :string
    validate match(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/)  # Validates query arguments
  end
end

validations do
  validate present([:title, :body]), on: [:create, :update]  # Multiple actions
end
```

- Create **custom validation modules** for complex validation logic:
  ```elixir
  defmodule MyApp.Validations.UniqueUsername do
    use Ash.Resource.Validation

    @impl true
    def init(opts), do: {:ok, opts}

    @impl true
    def validate(changeset, _opts, _context) do
      # Validation logic here
      # Return :ok or {:error, message}
    end
  end

  # Usage in resource:
  validate {MyApp.Validations.UniqueUsername, []}
  ```

- Make validations **atomic** when possible to ensure they work correctly with direct database operations by implementing the `atomic/3` callback in custom validation modules.

  ```elixir
  defmodule MyApp.Validations.IsEven do
    # transform and validate opts

    use Ash.Resource.Validation

    @impl true
    def init(opts) do
      if is_atom(opts[:attribute]) do
        {:ok, opts}
      else
        {:error, "attribute must be an atom!"}
      end
    end

    @impl true
    # This is optional, but useful to have in addition to validation
    # so you get early feedback for validations that can otherwise
    # only run in the datalayer
    def validate(changeset, opts, _context) do
      value = Ash.Changeset.get_attribute(changeset, opts[:attribute])

      if is_nil(value) || (is_number(value) && rem(value, 2) == 0) do
        :ok
      else
        {:error, field: opts[:attribute], message: "must be an even number"}
      end
    end

    @impl true
    def atomic(changeset, opts, context) do
      {:atomic,
        # the list of attributes that are involved in the validation
        [opts[:attribute]],
        # the condition that should cause the error
        # here we refer to the new value or the current value
        expr(rem(^atomic_ref(opts[:attribute]), 2) != 0),
        # the error expression
        expr(
          error(^InvalidAttribute, %{
            field: ^opts[:attribute],
            # the value that caused the error
            value: ^atomic_ref(opts[:attribute]),
            # the message to display
            message: ^(context.message || "%{field} must be an even number"),
            vars: %{field: ^opts[:attribute]}
          })
        )
      }
    end
  end
  ```

- **Avoid redundant validations** - Don't add validations that duplicate attribute constraints:
  ```elixir
  # WRONG - redundant validation
  attribute :name, :string do
    allow_nil? false
    constraints min_length: 1
  end

  validate present(:name) do  # Redundant! allow_nil? false already handles this
    message "Name is required"
  end

  validate attribute_does_not_equal(:name, "") do  # Redundant! min_length: 1 already handles this
    message "Name cannot be empty"
  end

  # CORRECT - let attribute constraints handle basic validation
  attribute :name, :string do
    allow_nil? false
    constraints min_length: 1
  end
  ```

## Using Preparations

Preparations modify queries before they're executed. They are used to add filters, sorts, or other query modifications based on the query context.

Common preparation patterns:

```elixir
# Built-in preparations
prepare build(sort: [created_at: :desc])
prepare build(filter: [active: true])

# Conditional preparations with where clauses
prepare build(filter: [visible: true]) do
  where argument_equals(:include_hidden, false)
end

# only_when_valid? - skip preparation if prior validations failed
prepare expensive_preparation() do
  only_when_valid? true
end

# Action-specific vs global preparations
actions do
  read :recent do
    prepare build(sort: [created_at: :desc], limit: 10)
  end
end

preparations do
  prepare build(filter: [deleted: false]), on: [:read, :update]
end
```

## Using Changes

Changes allow you to modify the changeset before it gets processed by an action. Unlike validations, changes can manipulate attribute values, add attributes, or perform other data transformations.

Common change patterns:

```elixir
# Built-in changes with conditions
change set_attribute(:status, "pending")
change relate_actor(:creator) do
  where present(:actor)
end
change atomic_update(:counter, expr(^counter + 1))

# Action-specific vs global changes
actions do
  create :sign_up do
    change set_attribute(:joined_at, expr(now()))  # Only for this action
  end
end

changes do
  change set_attribute(:updated_at, expr(now())), on: :update  # Multiple actions
  change manage_relationship(:items, type: :append), on: [:create, :update]
end
```

- Create **custom change modules** for reusable transformation logic:
  ```elixir
  defmodule MyApp.Changes.SlugifyTitle do
    use Ash.Resource.Change

    def change(changeset, _opts, _context) do
      title = Ash.Changeset.get_attribute(changeset, :title)

      if title do
        slug = title |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-")
        Ash.Changeset.change_attribute(changeset, :slug, slug)
      else
        changeset
      end
    end
  end

  # Usage in resource:
  change {MyApp.Changes.SlugifyTitle, []}
  ```

- Create a **change module with lifecycle hooks** to handle complex multi-step operations:

  ```elixir
  defmodule MyApp.Changes.ProcessOrder do
    use Ash.Resource.Change

    def change(changeset, _opts, context) do
      changeset
      |> Ash.Changeset.before_transaction(fn changeset ->
        # Runs before the transaction starts
        # Use for external API calls, logging, etc.
        MyApp.ExternalService.reserve_inventory(changeset, scope: context)
        changeset
      end)
      |> Ash.Changeset.before_action(fn changeset ->
        # Runs inside the transaction before the main action
        # Use for related database changes in the same transaction
        Ash.Changeset.change_attribute(changeset, :processed_at, DateTime.utc_now())
      end)
      |> Ash.Changeset.after_action(fn changeset, result ->
        # Runs inside the transaction after the main action, only on success
        # Use for related database changes that depend on the result
        MyApp.Inventory.update_stock_levels(result, scope: context)
        {changeset, result}
      end)
      |> Ash.Changeset.after_transaction(fn changeset,
        {:ok, result} ->
          # Runs after the transaction completes (success or failure)
          # Use for notifications, external systems, etc.
          MyApp.Mailer.send_order_confirmation(result, scope: context)
          {changeset, result}

        {:error, error} ->
          # Runs after the transaction completes (success or failure)
          # Use for notifications, external systems, etc.
          MyApp.Mailer.send_order_issue_notice(result, scope: context)
          {:error, error}
      end)
    end
  end

  # Usage in resource:
  change {MyApp.Changes.ProcessOrder, []}
  ```

## Atomic Changes

Atomic changes execute directly in the database as part of the update query, without requiring the record to be loaded first. This provides better performance and correct behavior under concurrent updates.

**Why atomic matters:**
- Avoids race conditions (e.g., incrementing a counter)
- Better performance (no round-trip to load the record)
- Required for bulk operations to work efficiently

**Built-in atomic changes:**
```elixir
# Increment a counter atomically
change atomic_update(:view_count, expr(view_count + 1))

# Set a value using an expression
change set_attribute(:updated_at, expr(now()))
```

**Making custom changes atomic:**
Implement the `atomic/3` callback to support atomic execution:

```elixir
defmodule MyApp.Changes.IncrementVersion do
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    # Fallback for non-atomic execution
    current = Ash.Changeset.get_attribute(changeset, :version) || 0
    Ash.Changeset.change_attribute(changeset, :version, current + 1)
  end

  @impl true
  def atomic(_changeset, _opts, _context) do
    # Atomic implementation - runs in the database
    {:atomic, %{version: expr(coalesce(version, 0) + 1)}}
  end
end
```

## Using `require_atomic? false`

By default, update and destroy actions require all changes and validations to support atomic execution. If they don't, the action will raise an error.

**IMPORTANT:** When you see `require_atomic? false` on an action, carefully consider whether it is truly necessary. This option should be used sparingly.

**When `require_atomic? false` is needed:**
- The action has `before_action` or `around_action` hooks that need to read or modify the record
- A change reads the current record state (e.g., `Ash.Changeset.get_data/2`) and cannot be rewritten atomically
- Complex validations that cannot be expressed as database expressions

**When `require_atomic? false` is NOT needed:**
- Simple attribute transformations (these can usually be made atomic)
- Setting timestamps or default values (use `expr(now())` instead)
- Incrementing counters (use `atomic_update/2`)
- After-action hooks (these don't prevent atomic execution)
- After-transaction hooks (these don't prevent atomic execution)

```elixir
actions do
  update :update do
    # AVOID unless truly necessary
    require_atomic? false
  end

  update :increment_views do
    # GOOD - fully atomic, no need to disable
    change atomic_update(:view_count, expr(view_count + 1))
  end
end
```

If you find yourself adding `require_atomic? false`, first check if your changes and validations can be rewritten with `atomic/3` callbacks. Only disable atomic requirements when the action genuinely needs to read or manipulate the record in hooks.

## Custom Modules vs. Anonymous Functions

Prefer to put code in its own module and refer to that in changes, preparations, validations etc.

For example, prefer this:

```elixir
defmodule MyApp.MyDomain.MyResource.Changes.SlugifyName do
  use Ash.Resource.Change

  def change(changeset, _, _) do
    Ash.Changeset.before_action(changeset, fn changeset, _ ->
      slug = MyApp.Slug.get()
      Ash.Changeset.force_change_attribute(changeset, :slug, slug)
    end)
  end
end

change MyApp.MyDomain.MyResource.Changes.SlugifyName
```

## Action Types

- **Read**: For retrieving records
- **Create**: For creating records
- **Update**: For changing records
- **Destroy**: For removing records
- **Generic**: For custom operations that don't fit the other types


<!-- ash:actions-end -->
<!-- ash:aggregates-start -->
## ash:aggregates usage
# Aggregates

Aggregates allow you to retrieve summary information over groups of related data, like counts, sums, or averages. Define aggregates in the `aggregates` block of a resource.

Aggregates can work over relationships or directly over unrelated resources:

```elixir
aggregates do
  # Related aggregates - use relationship path
  count :published_post_count, :posts do
    filter expr(published == true)
  end

  sum :total_sales, :orders, :amount

  exists :is_admin, :roles do
    filter expr(name == "admin")
  end

  # Unrelated aggregates - use resource module directly
  count :matching_profiles_count, Profile do
    filter expr(name == parent(name))
  end
  
  sum :total_report_score, Report, :score do
    filter expr(author_name == parent(name))
  end
  
  exists :has_reports, Report do
    filter expr(author_name == parent(name))
  end
end
```

For unrelated aggregates, use `parent/1` to reference fields from the source resource.

## Aggregate Types

- **count**: Counts related items meeting criteria
- **sum**: Sums a field across related items
- **exists**: Returns boolean indicating if matching related items exist (also supports unrelated resources)
- **first**: Gets the first related value matching criteria
- **list**: Lists the related values for a specific field
- **max**: Gets the maximum value of a field
- **min**: Gets the minimum value of a field
- **avg**: Gets the average value of a field

## Using Aggregates

```elixir
# Using code interface options (preferred)
users = MyDomain.list_users!(
  load: [:published_post_count, :total_sales],
  query: [
    filter: [published_post_count: [greater_than: 5]],
    sort: [published_post_count: :desc]
  ]
)

# Manual query building (for complex cases)
User |> Ash.Query.filter(published_post_count > 5) |> Ash.read!()

# Loading on existing records
Ash.load!(users, :published_post_count)
```

### Join Filters

For complex aggregates involving multiple relationships, use join filters:

```elixir
aggregates do
  sum :redeemed_deal_amount, [:redeems, :deal], :amount do
    # Filter on the aggregate as a whole
    filter expr(redeems.redeemed == true)

    # Apply filters to specific relationship steps
    join_filter :redeems, expr(redeemed == true)
    join_filter [:redeems, :deal], expr(active == parent(require_active))
  end
end
```

## Inline Aggregates

Use aggregates inline within expressions:

```elixir
# Related inline aggregates
calculate :grade_percentage, :decimal, expr(
  count(answers, query: [filter: expr(correct == true)]) * 100 /
  count(answers)
)

# Unrelated inline aggregates
calculate :profile_count, :integer, expr(
  count(Profile, filter: expr(name == parent(name)))
)

calculate :stats, :map, expr(%{
  profiles: count(Profile, filter: expr(active == true)),
  reports: count(Report, filter: expr(author_name == parent(name))),
  has_active_profile: exists(Profile, active == true and name == parent(name))
})
```


<!-- ash:aggregates-end -->
<!-- ash:authorization-start -->
## ash:authorization usage
# Authorization

- When performing administrative actions, you can bypass authorization with `authorize?: false`
- To run actions as a particular user, look that user up and pass it as the `actor` option
- Always set the actor on the query/changeset/input, not when calling the action
- Use policies to define authorization rules

```elixir
# Good
Post
|> Ash.Query.for_read(:read, %{}, actor: current_user)
|> Ash.read!()

# BAD, DO NOT DO THIS
Post
|> Ash.Query.for_read(:read, %{})
|> Ash.read!(actor: current_user)
```

## Policies

To use policies, add the `Ash.Policy.Authorizer` to your resource:

```elixir
defmodule MyApp.Post do
  use Ash.Resource,
    domain: MyApp.Blog,
    authorizers: [Ash.Policy.Authorizer]

  # Rest of resource definition...
end
```

## Policy Basics

Policies determine what actions on a resource are permitted for a given actor. Define policies in the `policies` block:

```elixir
policies do
  # A simple policy that applies to all read actions
  policy action_type(:read) do
    # Authorize if record is public
    authorize_if expr(public == true)

    # Authorize if actor is the owner
    authorize_if relates_to_actor_via(:owner)
  end

  # A policy for create actions
  policy action_type(:create) do
    # Only allow active users to create records
    forbid_unless actor_attribute_equals(:active, true)

    # Ensure the record being created relates to the actor
    authorize_if relating_to_actor(:owner)
  end
end
```

## Policy Evaluation Flow

Policies evaluate from top to bottom with the following logic:

1. All policies that apply to an action must pass for the action to be allowed
2. Within each policy, checks evaluate from top to bottom
3. The first check that produces a decision determines the policy result
4. If no check produces a decision, the policy defaults to forbidden

## IMPORTANT: Policy Check Logic

**the first check that yields a result determines the policy outcome**

```elixir
# WRONG - This is OR logic, not AND logic!
policy action_type(:update) do
  authorize_if actor_attribute_equals(:admin?, true)    # If this passes, policy passes
  authorize_if relates_to_actor_via(:owner)           # Only checked if first fails
end
```

To require BOTH conditions in that example, you would use `forbid_unless` for the first condition:

```elixir
# CORRECT - This requires BOTH conditions
policy action_type(:update) do
  forbid_unless actor_attribute_equals(:admin?, true)  # Must be admin
  authorize_if relates_to_actor_via(:owner)           # AND must be owner
end
```

Alternative patterns for AND logic:
- Use multiple separate policies (each must pass independently)
- Use a single complex expression with `expr(condition1 and condition2)`
- Use `forbid_unless` for required conditions, then `authorize_if` for the final check

## Bypass Policies

Use bypass policies to allow certain actors to bypass other policy restrictions. This should be used almost exclusively for admin bypasses.

```elixir
policies do
  # Bypass policy for admins - if this passes, other policies don't need to pass
  bypass actor_attribute_equals(:admin, true) do
    authorize_if always()
  end

  # Regular policies follow...
  policy action_type(:read) do
    # ...
  end
end
```

## Field Policies

Field policies control access to specific fields (attributes, calculations, aggregates):

```elixir
field_policies do
  # Only supervisors can see the salary field
  field_policy :salary do
    authorize_if actor_attribute_equals(:role, :supervisor)
  end

  # Allow access to all other fields
  field_policy :* do
    authorize_if always()
  end
end
```

## Policy Checks

There are two main types of checks used in policies:

1. **Simple checks** - Return true/false answers (e.g., "is the actor an admin?")
2. **Filter checks** - Return filters to apply to data (e.g., "only show records owned by the actor")

You can use built-in checks or create custom ones:

```elixir
# Built-in checks
authorize_if actor_attribute_equals(:role, :admin)
authorize_if relates_to_actor_via(:owner)
authorize_if expr(public == true)

# Custom check module
authorize_if MyApp.Checks.ActorHasPermission
```

### Custom Policy Checks

Create custom checks by implementing `Ash.Policy.SimpleCheck` or `Ash.Policy.FilterCheck`:

```elixir
# Simple check - returns true/false
defmodule MyApp.Checks.ActorHasRole do
  use Ash.Policy.SimpleCheck

  def match?(%{role: actor_role}, _context, opts) do
    actor_role == (opts[:role] || :admin)
  end
  def match?(_, _, _), do: false
end

# Filter check - returns query filter
defmodule MyApp.Checks.VisibleToUserLevel do
  use Ash.Policy.FilterCheck

  def filter(actor, _authorizer, _opts) do
    expr(visibility_level <= ^actor.user_level)
  end
end

# Usage
policy action_type(:read) do
  authorize_if {MyApp.Checks.ActorHasRole, role: :manager}
  authorize_if MyApp.Checks.VisibleToUserLevel
end
```


<!-- ash:authorization-end -->
<!-- ash:calculations-start -->
## ash:calculations usage
# Calculations

Calculations allow you to define derived values based on a resource's attributes or related data. Define calculations in the `calculations` block of a resource:

```elixir
calculations do
  # Simple expression calculation
  calculate :full_name, :string, expr(first_name <> " " <> last_name)

  # Expression with conditions
  calculate :status_label, :string, expr(
    cond do
      status == :active -> "Active"
      status == :pending -> "Pending Review"
      true -> "Inactive"
    end
  )

  # Using module calculations for more complex logic
  calculate :risk_score, :integer, {MyApp.Calculations.RiskScore, min: 0, max: 100}
end
```

## Expression Calculations

Expression calculations use Ash expressions and can be pushed down to the data layer when possible:

```elixir
calculations do
  # Simple string concatenation
  calculate :full_name, :string, expr(first_name <> " " <> last_name)

  # Math operations
  calculate :total_with_tax, :decimal, expr(amount * (1 + tax_rate))

  # Date manipulation
  calculate :days_since_created, :integer, expr(
    date_diff(^now(), inserted_at, :day)
  )
end
```

## Expressions

In order to use expressions outside of resources, changes, preparations etc. you will need to use `Ash.Expr`.

It provides both `expr/1` and template helpers like `actor/1` and `arg/1`.

For example:

```elixir
import Ash.Expr

Author
|> Ash.Query.aggregate(:count_of_my_favorited_posts, :count, [:posts], query: [
  filter: expr(favorited_by(user_id: ^actor(:id)))
])
```

See the expressions guide for more information on what is available in expresisons and
how to use them.

## Module Calculations

For complex calculations, create a module that implements `Ash.Resource.Calculation`:

```elixir
defmodule MyApp.Calculations.FullName do
  use Ash.Resource.Calculation

  # Validate and transform options
  @impl true
  def init(opts) do
    {:ok, Map.put_new(opts, :separator, " ")}
  end

  # Specify what data needs to be loaded
  @impl true
  def load(_query, _opts, _context) do
    [:first_name, :last_name]
  end

  # Implement the calculation logic
  @impl true
  def calculate(records, opts, _context) do
    Enum.map(records, fn record ->
      [record.first_name, record.last_name]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(opts.separator)
    end)
  end
end

# Usage in a resource
calculations do
  calculate :full_name, :string, {MyApp.Calculations.FullName, separator: ", "}
end
```

## Calculations with Arguments

You can define calculations that accept arguments:

```elixir
calculations do
  calculate :full_name, :string, expr(first_name <> ^arg(:separator) <> last_name) do
    argument :separator, :string do
      allow_nil? false
      default " "
      constraints [allow_empty?: true, trim?: false]
    end
  end
end
```

## Using Calculations

```elixir
# Using code interface options (preferred)
users = MyDomain.list_users!(load: [full_name: [separator: ", "]])

# Filtering and sorting
users = MyDomain.list_users!(
  query: [
    filter: [full_name: [separator: " ", value: "John Doe"]],
    sort: [full_name: {[separator: " "], :asc}]
  ]
)

# Manual query building (for complex cases)
User |> Ash.Query.load(full_name: [separator: ", "]) |> Ash.read!()

# Loading on existing records
Ash.load!(users, :full_name)
```

### Code Interface for Calculations

Define calculation functions on your domain for standalone use:

```elixir
# In your domain
resource User do
  define_calculation :full_name, args: [:first_name, :last_name, {:optional, :separator}]
end

# Then call it directly
MyDomain.full_name("John", "Doe", ", ")  # Returns "John, Doe"
```


<!-- ash:calculations-end -->
<!-- ash:code_interfaces-start -->
## ash:code_interfaces usage
# Code Interfaces

Domains and Resources can define code interfaces. Prefer writing code interfaces instead of regular elixir functions.

Use code interfaces on domains to define the contract for calling into Ash resources. See the [Code interface guide for more](https://hexdocs.pm/ash/code-interfaces.html).

Define code interfaces on the domain, like this:

```elixir
resource ResourceName do
  define :fun_name, action: :action_name
end
```

For more complex interfaces with custom transformations:

```elixir
define :custom_action do
  action :action_name
  args [:arg1, :arg2]

  custom_input :arg1, MyType do
    transform do
      to :target_field
      using &MyModule.transform_function/1
    end
  end
end
```

Prefer using the primary read action for "get" style code interfaces, and using `get_by` when the field you are looking up by is the primary key or has an `identity` on the resource.

```elixir
resource ResourceName do
  define :get_thing, action: :read, get_by: [:id]
end
```

**Avoid direct Ash calls in web modules** - Don't use `Ash.get!/2` and `Ash.load!/2` directly in LiveViews/Controllers, similar to avoiding `Repo.get/2` outside context modules:

You can also pass additional inputs in to code interfaces before the options:

```elixir
resource ResourceName do
  define :create, action: :action_name, args: [:field1]
end
```

```elixir
Domain.create!(field1_value, %{field2: field2_value}, actor: current_user)
```

You should generally prefer using this map of extra inputs over defining optional arguments.

```elixir
# BAD - in LiveView/Controller
group = MyApp.Resource |> Ash.get!(id) |> Ash.load!(rel: [:nested])

# GOOD - use code interface with get_by
resource DashboardGroup do
  define :get_dashboard_group_by_id, action: :read, get_by: [:id]
end

# Then call:
MyApp.Domain.get_dashboard_group_by_id!(id, load: [rel: [:nested]])
```

**Code interface options** - Prefer passing options directly to code interface functions rather than building queries manually:

```elixir
# PREFERRED - Use the query option for filter, sort, limit, etc.
# the query option is passed to `Ash.Query.build/2`
posts = MyApp.Blog.list_posts!(
  query: [
    filter: [status: :published],
    sort: [published_at: :desc],
    limit: 10
  ],
  load: [author: :profile, comments: [:author]]
)

# All query-related options go in the query parameter
users = MyApp.Accounts.list_users!(
  query: [filter: [active: true], sort: [created_at: :desc]],
  load: [:profile]
)

# AVOID - Verbose manual query building
query = MyApp.Post |> Ash.Query.filter(...) |> Ash.Query.load(...)
posts = Ash.read!(query)
```

Supported options: `load:`, `query:` (which accepts `filter:`, `sort:`, `limit:`, `offset:`, etc.), `page:`, `stream?:`

**Using Scopes in LiveViews** - When using `Ash.Scope`, the scope will typically be assigned to `scope` in LiveViews and used like so:

```elixir
# In your LiveView
MyApp.Blog.create_post!("new post", scope: socket.assigns.scope)
```

Inside action hooks and callbacks, use the provided `context` parameter as your scope instead:

```elixir
|> Ash.Changeset.before_transaction(fn changeset, context ->
  MyApp.ExternalService.reserve_inventory(changeset, scope: context)
  changeset
end)
```

## Authorization Functions

For each action defined in a code interface, Ash automatically generates corresponding authorization check functions:

- `can_action_name?(actor, params \\ %{}, opts \\ [])` - Returns `true`/`false` for authorization checks
- `can_action_name(actor, params \\ %{}, opts \\ [])` - Returns `{:ok, true/false}` or `{:error, reason}`

Example usage:
```elixir
# Check if user can create a post
if MyApp.Blog.can_create_post?(current_user) do
  # Show create button
end

# Check if user can update a specific post
if MyApp.Blog.can_update_post?(current_user, post) do
  # Show edit button
end

# Check if user can destroy a specific comment
if MyApp.Blog.can_destroy_comment?(current_user, comment) do
  # Show delete button
end
```

These functions are particularly useful for conditional rendering of UI elements based on user permissions.


<!-- ash:code_interfaces-end -->
<!-- ash:code_structure-start -->
## ash:code_structure usage
# Code Structure & Organization

- Organize code around domains and resources
- Each resource should be focused and well-named
- Create domain-specific actions rather than generic CRUD operations
- Put business logic inside actions rather than in external modules
- Use resources to model your domain entities

<!-- ash:code_structure-end -->
<!-- ash:data_layers-start -->
## ash:data_layers usage
# Data Layers

Data layers determine how resources are stored and retrieved. Examples of data layers:

- **Postgres**: For storing resources in PostgreSQL (via `AshPostgres`)
- **ETS**: For in-memory storage (`Ash.DataLayer.Ets`)
- **Mnesia**: For distributed storage (`Ash.DataLayer.Mnesia`)
- **Embedded**: For resources embedded in other resources (`data_layer: :embedded`) (typically JSON under the hood)
- **Ash.DataLayer.Simple**: For resources that aren't persisted at all. Leave off the data layer, as this is the default.

Specify a data layer when defining a resource:

```elixir
defmodule MyApp.Post do
  use Ash.Resource,
    domain: MyApp.Blog,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "posts"
    repo MyApp.Repo
  end

  # ... attributes, relationships, etc.
end
```

For embedded resources:

```elixir
defmodule MyApp.Address do
  use Ash.Resource,
    data_layer: :embedded

  attributes do
    attribute :street, :string
    attribute :city, :string
    attribute :state, :string
    attribute :zip, :string
  end
end
```

Each data layer has its own configuration options and capabilities. Refer to the rules & documentation of the specific data layer package for more details.


<!-- ash:data_layers-end -->
<!-- ash:exist_expressions-start -->
## ash:exist_expressions usage
# Exists Expressions

Use `exists/2` to check for the existence of records, either through relationships or unrelated resources:

### Related Exists

```elixir
# Check if user has any admin roles
Ash.Query.filter(User, exists(roles, name == "admin"))

# Check if post has comments with high scores
Ash.Query.filter(Post, exists(comments, score > 50))
```

### Unrelated Exists

```elixir
# Check if any profile exists with the same name
Ash.Query.filter(User, exists(Profile, name == parent(name)))

# Check if user has any reports
Ash.Query.filter(User, exists(Report, author_name == parent(name)))

# Complex existence checks
Ash.Query.filter(User, 
  active == true and 
  exists(Profile, active == true and name == parent(name))
)
```

Unrelated exists expressions automatically apply authorization using the target resource's primary read action. Use `parent/1` to reference fields from the source resource.

<!-- ash:exist_expressions-end -->
<!-- ash:generating_code-start -->
## ash:generating_code usage
# Generating Code

Use `mix ash.gen.*` tasks as a basis for code generation when possible. Check the task docs with `mix help <task>`.
Be sure to use `--yes` to bypass confirmation prompts. Use `--yes --dry-run` to preview the changes.


<!-- ash:generating_code-end -->
<!-- ash:migrations-start -->
## ash:migrations usage
# Migrations and Schema Changes

After creating or modifying Ash code, run `mix ash.codegen <short_name_describing_changes>` to ensure any required additional changes are made (like migrations are generated). The name of the migration should be lower_snake_case. In a longer running dev session it's usually better to use `mix ash.codegen --dev` as you go and at the end run the final codegen with a sensible name describing all the changes made in the session.


<!-- ash:migrations-end -->
<!-- ash:query_filter-start -->
## ash:query_filter usage
# Ash.Query.filter is a macro

**Important**: You must `require Ash.Query` if you want to use `Ash.Query.filter/2`, as it is a macro.

If you see errors like the following:

```
Ash.Query.filter(MyResource, id == ^id)
error: misplaced operator ^id

The pin operator ^ is supported only inside matches or inside custom macros...
```

```
iex(3)> Ash.Query.filter(MyResource, something == true)
error: undefined variable "something"
└─ iex:3
```

You are very likely missing a `require Ash.Query`

## Common Query Operations

- **Filter**: `Ash.Query.filter(query, field == value)`
- **Sort**: `Ash.Query.sort(query, field: :asc)`
- **Load relationships**: `Ash.Query.load(query, [:author, :comments])`
- **Limit**: `Ash.Query.limit(query, 10)`
- **Offset**: `Ash.Query.offset(query, 20)`


<!-- ash:query_filter-end -->
<!-- ash:querying_data-start -->
## ash:querying_data usage
# Querying Data

Use `Ash.Query` to build queries for reading data from your resources. The query module provides a declarative way to filter, sort, and load data.


<!-- ash:querying_data-end -->
<!-- ash:relationships-start -->
## ash:relationships usage
# Relationships

Relationships describe connections between resources and are a core component of Ash. Define relationships in the `relationships` block of a resource.

## Best Practices for Relationships

- Be descriptive with relationship names (e.g., use `:authored_posts` instead of just `:posts`)
- Configure foreign key constraints in your data layer if they have them (see `references` in AshPostgres)
- Always choose the appropriate relationship type based on your domain model

### Relationship Types

- For Polymorphic relationships, you can model them using `Ash.Type.Union`; see the “Polymorphic Relationships” guide for more information.

```elixir
relationships do
  # belongs_to - adds foreign key to source resource
  belongs_to :owner, MyApp.User do
    allow_nil? false
    attribute_type :integer  # defaults to :uuid
  end

  # has_one - foreign key on destination resource
  has_one :profile, MyApp.Profile

  # has_many - foreign key on destination resource, returns list
  has_many :posts, MyApp.Post do
    filter expr(published == true)
    sort published_at: :desc
  end

  # many_to_many - requires join resource
  many_to_many :tags, MyApp.Tag do
    through MyApp.PostTag
    source_attribute_on_join_resource :post_id
    destination_attribute_on_join_resource :tag_id
  end
end
```

The join resource must be defined separately:

```elixir
defmodule MyApp.PostTag do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id
    # Add additional attributes if you need metadata on the relationship
    attribute :added_at, :utc_datetime_usec do
      default &DateTime.utc_now/0
    end
  end

  relationships do
    belongs_to :post, MyApp.Post, primary_key?: true, allow_nil?: false
    belongs_to :tag, MyApp.Tag, primary_key?: true, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end
end
```

## Loading Relationships

```elixir
# Using code interface options (preferred)
post = MyDomain.get_post!(id, load: [:author, comments: [:author]])

# Complex loading with filters
posts = MyDomain.list_posts!(
  query: [load: [comments: [filter: [is_approved: true], limit: 5]]]
)

# Manual query building (for complex cases)
MyApp.Post
|> Ash.Query.load(comments: MyApp.Comment |> Ash.Query.filter(is_approved == true))
|> Ash.read!()

# Loading on existing records
Ash.load!(post, :author)
```

Prefer to use the `strict?` option when loading to only load necessary fields on related data.

```elixir
MyApp.Post
|> Ash.Query.load([comments: [:title]], strict?: true)
```

## Managing Relationships

There are two primary ways to manage relationships in Ash:

### 1. Using `change manage_relationship/2-3` in Actions
Use this when input comes from action arguments:

```elixir
actions do
  update :update do
    # Define argument for the related data
    argument :comments, {:array, :map} do
      allow_nil? false
    end

    argument :new_tags, {:array, :map}

    # Link argument to relationship management
    change manage_relationship(:comments, type: :append)

    # For different argument and relationship names
    change manage_relationship(:new_tags, :tags, type: :append)
  end
end
```

### 2. Using `Ash.Changeset.manage_relationship/3-4` in Custom Changes
Use this when building values programmatically:

```elixir
defmodule MyApp.Changes.AssignTeamMembers do
  use Ash.Resource.Change

  def change(changeset, _opts, context) do
    members = determine_team_members(changeset, context.actor)

    Ash.Changeset.manage_relationship(
      changeset,
      :members,
      members,
      type: :append_and_remove
    )
  end
end
```

### Quick Reference - Management Types
- `:append` - Add new related records, ignore existing
- `:append_and_remove` - Add new related records, remove missing
- `:remove` - Remove specified related records
- `:direct_control` - Full CRUD control (create/update/destroy)
- `:create` - Only create new records

### Quick Reference - Common Options
- `on_lookup: :relate` - Look up and relate existing records
- `on_no_match: :create` - Create if no match found
- `on_match: :update` - Update existing matches
- `on_missing: :destroy` - Delete records not in input
- `value_is_key: :name` - Use field as key for simple values

For comprehensive documentation, see the [Managing Relationships](https://hexdocs.pm/ash/relationships.html#managing-relationships) section.

### Examples

Creating a post with tags:
```elixir
MyDomain.create_post!(%{
  title: "New Post",
  body: "Content here...",
  tags: [%{name: "elixir"}, %{name: "ash"}]  # Creates new tags
})

# Updating a post to replace its tags
MyDomain.update_post!(post, %{
  tags: [tag1.id, tag2.id]  # Replaces tags with existing ones by ID
})
```


<!-- ash:relationships-end -->
<!-- ash:testing-start -->
## ash:testing usage
# Testing

When testing resources:
- Test your domain actions through the code interface
- Use test utilities in `Ash.Test`
- Test authorization policies work as expected using `Ash.can?`
- Use `authorize?: false` in tests where authorization is not the focus
- Write generators using `Ash.Generator`
- Prefer to use raising versions of functions whenever possible, as opposed to pattern matching

## Preventing Deadlocks in Concurrent Tests

When running tests concurrently, using fixed values for identity attributes can cause deadlock errors. Multiple tests attempting to create records with the same unique values will conflict.

### Use Globally Unique Values

Always use globally unique values for identity attributes in tests:

```elixir
# BAD - Can cause deadlocks in concurrent tests
%{email: "test@example.com", username: "testuser"}

# GOOD - Use globally unique values
%{
  email: "test-#{System.unique_integer([:positive])}@example.com",
  username: "user_#{System.unique_integer([:positive])}",
  slug: "post-#{System.unique_integer([:positive])}"
}
```

### Creating Reusable Test Generators

For better organization, create a generator module:

```elixir
defmodule MyApp.TestGenerators do
  use Ash.Generator

  def user(opts \\ []) do
    changeset_generator(
      User,
      :create,
      defaults: [
        email: "user-#{System.unique_integer([:positive])}@example.com",
        username: "user_#{System.unique_integer([:positive])}"
      ],
      overrides: opts
    )
  end
end

# In your tests
test "concurrent user creation" do
  users = MyApp.TestGenerators.generate_many(user(), 10)
  # Each user has unique identity attributes
end
```

This applies to ANY field used in identity constraints, not just primary keys. Using globally unique values prevents frustrating intermittent test failures in CI environments.

<!-- ash:testing-end -->
<!-- usage-rules-end -->
