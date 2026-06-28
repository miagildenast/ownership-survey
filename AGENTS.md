This is a web application written using the Phoenix web framework.

## Project guidelines

- Use `mix precommit` alias when you are done with all changes and fix any pending issues
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

- **Produce world-class UI designs** with a focus on usability, aesthetics, and modern design principles
- Implement **subtle micro-interactions** (e.g., button hover effects, and smooth transitions)
- Ensure **clean typography, spacing, and layout balance** for a refined, premium look
- Focus on **delightful details** like hover effects, loading states, and smooth page transitions


# Project Description: Haiku Study

> This file describes the conceptual idea behind the project so it can serve as a
> reference for implementation and decisions later. It is intentionally kept high-level;
> open questions are collected at the end.

## Overview

The project is a tool for a **research study** in which participants (subjects)
**write haikus**. It investigates the effect of two factors on the writing experience and
the result:

1. **Topic prompt** – with a given topic vs. without a topic (free choice)
2. **AI assistance** – with AI (ping-pong mode) vs. without AI (writing alone)

After each run, participants rate their experience/result on a **Likert scale**
(questionnaire).

## Study Design

### Two crossed factors

The study has two crossed binary factors → **4 writing runs** per participant, plus a
fifth modification run.

- **`topic_source`** (the "condition") — `:assigned` (a topic is given) | `:free` (the
  participant chooses the topic)
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

Alternating writing: one passage from the user, one passage from the AI, one passage from
the user, and so on. A haiku is created jointly, turn by turn.

### Fifth run (modification)

An additional, **fifth run** builds on the results:

1. The **"best" run** of the four previous ones is taken as the starting point.
   - **Determination**: highest **average** across the run's Likert items.
   - All Likert questions are **positively coded** (higher = better), so they can be
     averaged directly without reverse-scoring.
   - Tie-break on equal scores: still to be decided (see Open Questions).
2. The chatbot modifies the haiku. There are **three variants**, and which one a
   participant gets is **chosen at random**:
   - **5a** – only **one word** in the whole haiku is changed
   - **5b** – **one line** is changed
   - **5c** – **two lines** are changed
3. Afterwards the **Likert scale is asked again** (rating of the modified version).

## Access & Identification

- **No classic login** (no username/password).
- Participants enter the application via a link with a token:
  ```
  /start?token=%caseToken%
  ```
  The `%caseToken%` placeholder is filled by the **upstream study tool** (e.g. a
  survey/panel software). The token identifies the case.
- The **caseId** is derived from / mapped to the token.

### Return to the originating tool

- At the end of the **last run**, a **UUID** is displayed.
- The participant takes this UUID back into the originating tool so the datasets can be
  **matched later** (mapping between our dataset and the external tool).

## Participant flow (high level)

1. Entry via `/start?token=…`.
2. Four runs in nested-block order (both `ai_mode` values of one `topic_source`, then the
   next `topic_source` — see Study Design):
   - optional topic display / topic choice (depending on `topic_source`),
   - writing phase (alone or ping-pong with chatbot, depending on `ai_mode`),
   - Likert survey.
3. Fifth run: modification on the best haiku (random variant 5a/5b/5c) + Likert.
4. Display of the **UUID** (run/session ID) to return to the originating tool.

## Data model

Persisted **relationally via AshPostgres** (the app already uses Postgres + AshPostgres):
a **`session`** resource `has_many` **`run`** resources. JSON is **not** the storage format
— it is only an **export artifact**, generated on demand from a read action (load `session`
with its `runs` and serialize, e.g. via `Jason`). Field names below are the proposed domain
attribute names (snake_case); exported JSON keys mirror them.

### `session` (one per participant / `case_token`)

- `case_id` – derived from the entry token; mapping to the external tool
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
- `topic` – the actual topic text (the assigned one, or the participant's chosen one)
- `transcript` – the messages (user + AI), in order
- `final_haiku` – the finished haiku (separate from the transcript, for easy analysis)
- `likert` – questionnaire answers (all items positively coded)
- `started_at` / `completed_at`

### Modification run (the fifth, `kind: :modification`)

- `variant` – `:a` (one word) | `:b` (one line) | `:c` (two lines), assigned at random
- `source_run_index` – which writing run was the "best" (highest Likert average) and used
  as the basis
- `original_haiku` / `modified_haiku` – before/after the chatbot's change
- `likert` – questionnaire answers on the modified version

## Technical context (current state)

- Phoenix/Ash application with an existing chat (LiveView, generated via `ash_ai.gen.chat`).
- The LLM is config-driven (`OwnershipAshChat.LLM`, `lib/ownership_ash_chat/llm.ex`): prod
  via Anthropic/Claude, dev/test via a local OpenAI-compatible endpoint (LM Studio). Config
  lives in `config/runtime.exs` (env-branched), tunable via `LLM_MODEL`, `LLM_BASE_URL`,
  `LLM_API_KEY` / `ANTHROPIC_API_KEY`.
- **Tools are disabled** in `Chat.Message.Changes.Respond` (`tools: false`): the local
  model (Gemma) has no reliable function-calling, and the study does not need tools. The
  chat runs as a plain streaming text flow.
- The existing chat flow (`Chat.Message.Changes.Respond`, `Chat.Conversation`) is the base,
  but must be adapted for the study setup (phases, conditions, ping-pong logic,
  questionnaires, token entry instead of auth).

### Repo conventions

- **`AGENTS.md` is the single source of truth**; `CLAUDE.md` is a symlink to it. Edit
  `AGENTS.md`, never `CLAUDE.md` directly.
- `mix usage_rules.sync` targets `AGENTS.md` (see `mix.exs`) and only rewrites the
  `<!-- usage-rules-* -->` managed block — content above it (this description) is safe.

## Implementation plan (lean, in order)

Build dependencies first. Critical path: 1 → 3 → 4 → 5 → 6 → 7. Step 2 can run in parallel
after 1; step 8 any time after 1.

1. **Domain + persistence** (foundation) — a `Study` domain (or extend `Chat`); enums
   `topic_source`, `ai_mode`, `run_kind`, `variant`; `session` and `run` resources
   (AshPostgres, `has_many`/`belongs_to`); `mix ash.codegen` → migration.
2. **Token entry** (replaces auth) — route `/start?token=…`; action that resolves the token
   to a `case_id` and creates a `session` (`:in_progress`); reject invalid tokens.
3. **Randomization** — on session create, draw `topic_source_order` and the `ai_mode` order
   per block; create the 4 `kind: :writing` runs with their `run_index`.
4. **Writing flow** (core) — `:without_ai` plain input; `:with_ai` ping-pong reusing the
   existing chat/`Respond`; capture `topic`, `transcript`, `final_haiku` per run.
5. **Likert** — questionnaire at each run's end → store `likert` (items positively coded).
6. **Fifth run** — pick best run (highest Likert average); draw `variant :a/:b/:c`; chatbot
   modifies the haiku; ask Likert again.
7. **End screen** — show `session_id` (UUID) for return to the originating tool; mark
   session `:completed`.
8. **Export** — read action loading `session` + `runs`, serialized to JSON.

## Open questions (to clarify before implementation)

1. **"Best" run for run 5**: highest Likert average, all items positively coded (clarified).
   Open only: **tie-break** on equal scores (e.g. random, or a preferred
   `topic_source`/`ai_mode`).
2. **Modification variant distribution**: are `:a/:b/:c` drawn uniformly at random, or
   balanced (e.g. against the best run's `topic_source`/`ai_mode`)?
3. **Topic prompt**: Fixed topic pool, drawn at random, or configured per study?
4. **Ping-pong**: Fixed number of rounds? Who starts (user or AI)? When does a run end?
5. **Likert questionnaire**: Which concrete items, which scale (e.g. 5- or 7-point)? Same
   items across all five runs?
6. **Token security**: How is `caseToken` validated (signature, expiry, single use)? What
   happens on an invalid/missing token?
7. **Persistence**: resolved — store relationally via AshPostgres (`session` `has_many`
   `run`); JSON is only an on-demand export artifact from a read action, not the storage
   format. Open only: export trigger/format details (single session vs. bulk, file vs.
   download endpoint).
8. **Re-entry**: May a participant resume an interrupted session (same token)? Or strictly
   single use?
9. **UI/chatbot language**: German? English? (Haiku instructions and system prompt
   accordingly.)


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
<!-- usage-rules-end -->
