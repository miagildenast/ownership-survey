This is a web application written using the Phoenix web framework.

## Project guidelines

- **`mix precommit` is the required final gate for every Elixir change.** Run it once after
  all changes are made and fix every issue it reports before considering the work done — never
  treat a change as complete on the strength of piecemeal checks alone. Individual steps
  (`mix compile`, `mix format <file>`, a single `mix test <file>`) **may** be used freely
  *during* development for debugging or fast feedback, but they do **not** substitute for the
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
- Participants enter the application via a link carrying a `case_id`:
  ```
  /start?case_id=%caseToken%
  ```
  The `%caseToken%` placeholder is filled by the **upstream study tool** (e.g. a
  survey/panel software) into the `case_id` query param. The value identifies the case.
- The **`case_id`** is the value passed in the link; it maps our session to the external
  tool. (Lean first pass: the value is treated as the `case_id` verbatim — no
  signature/expiry yet; see open question #6.)

### Return to the originating tool

- At the end of the **last run**, a **UUID** is displayed.
- The participant takes this UUID back into the originating tool so the datasets can be
  **matched later** (mapping between our dataset and the external tool).

## Participant flow (high level)

1. Entry via `/start?case_id=…`.
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

### `session` (one per participant / `case_id`)

- `case_id` – the value from the entry link; mapping to the external tool
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
  questionnaires, `case_id` entry instead of auth).

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

## Implementation plan (lean, in order)

Build dependencies first. Critical path: 1 → 3 → 4 → 5 → 6 → 7. Step 2 can run in parallel
after 1; step 8 any time after 1.

1. ~~**Domain + persistence** (foundation) — a `Study` domain (or extend `Chat`); enums
   `topic_source`, `ai_mode`, `run_kind`, `variant`; `session` and `run` resources
   (AshPostgres, `has_many`/`belongs_to`); `mix ash.codegen` → migration.~~ ✅ **Done** —
   `OwnershipAshChat.Study` domain, `Types.{TopicSource,AiMode,RunKind,Variant,SessionStatus}`,
   `Session has_many Run` (FK cascade), migration + tests (`Ash.Generator`).
2. ~~**`case_id` entry** (replaces auth) — route `/start?case_id=…`; action that resolves
   the `case_id` and creates a `session` (`:in_progress`); reject invalid (blank)
   `case_id`.~~ ✅ **Done** — `Session.start` upsert action (resumes on re-entry via
   `unique_case_id` identity), `Study.start_session` code interface,
   `StartController` (`/start` → session cookie → `/study` flow), tests.
3. ~~**Randomization** — on session create, draw `topic_source_order` and the `ai_mode` order
   per block; create the 4 `kind: :writing` runs with their `run_index`.~~ ✅ **Done** —
   `Study.Randomization.draw_writing_plan/0` (pure: nested block draw, one of 8 sequences);
   `Session.Changes.SeedRuns` forces `topic_source_order` + `started_at` and seeds the 4
   `:writing` runs in an `after_action` hook, wired into the `:start` action. Guarded so an
   upsert resume never re-seeds (idempotent, open question #8). Session-driven flow at
   `/study` (`StudySessionLive`) walks the runs, **Weiter** button advances on completion;
   shared `run_panel/1` component; one-click dev entry `/dev/study/new`. Tests:
   `randomization_test.exs`, `study_test.exs` (seed + idempotency), `study_session_live_test.exs`.
4. ~~**Writing flow** (core) — `:without_ai` plain input; `:with_ai` ping-pong reusing the
   existing chat/`Respond`; capture `topic`, `transcript`, `final_haiku` per run.~~ ✅
   **Done** — `Study.{set_run_topic,add_user_passage}` actions persist `topic` /
   `transcript` (embedded `%{"role","text"}` passages); `final_haiku` is auto-assembled
   on completion (see 4b). `Study.PingPong` generates the AI passage via central `LLM` +
   `ReqLLM` (injectable responder for tests); dev harness `StudyWritingLive`
   (`/dev/study/run/:run_id`) walks it end to end. Follow-ups 4a/4b done below.

   4a. ~~**Line-specific ping-pong prompt**~~ ✅ **Done** — `PingPong.second_line_prompt/1`
   builds the literal prompt below (system = global preamble, user = the prompt) and
   `generate_passage/2` strips stray quotes/whitespace. Topic intentionally NOT injected
   (literal spec); TODO in the module notes injecting it for `:assigned` runs. The AI
   passage is a concrete haiku line under hard constraints (exactly one line, 7 syllables,
   German, no quotes/explanations/surrounding text) — the **second line**, given the
   human's first line:

       Generate the second line of a German haiku.
       First line:
       „[LINE1]“
       Constraints:
       „Output exactly one line.“
       „The line must contain 7 syllables.“
       „Output language: German.“
       „Do not add quotation marks.“
       „Do not add explanations.“
       „Do not add any text before or after the line.“
       Return only the second line.

   4b. ~~**Auto-end after 3 lines**~~ ✅ **Done** — runs hold exactly `PingPong.lines()`
   (3, config `:ping_pong_lines`) lines: `:with_ai` = `[human, LLM, human]` (AI takes only
   line 2), `:without_ai` = three human lines. `Run.Changes.AddPassage` generates the AI
   line only after the first human passage and, on reaching the limit, auto-completes the
   run — assembling `final_haiku` from the transcript (joined by `\n`, **never** entered by
   the user) and stamping `completed_at`. Replaced the old `ping_pong_rounds` user-count
   rule; the standalone `set_final_haiku` action was removed.
5. ~~**Likert** — questionnaire at each run's end → store `likert` (items positively
   coded).~~ ✅ **Done** — `OwnershipAshChat.Study.Likert` is the single source of truth for
   items + scale (3 placeholder items, 5-point scale `1..5`; final items are open question
   #5). `Run.submit_likert` (`accept [:likert]`) stores the answer map, validated by
   `Run.Validations.LikertAnswers` (exactly the expected keys, every value within the
   scale); code interface `Study.submit_likert`. Stored as string-keyed integers, e.g.
   `%{"zufriedenheit" => 5}`, mirroring `transcript`. Surfaced in the dev harness
   `StudyWritingLive` (`/dev/study/run/:run_id`): the questionnaire appears once the run has
   auto-completed (`completed_at` set), submits, then shows the saved answers read-only.
6. ~~**Fifth run** — pick best run (highest Likert average); draw `variant :a/:b/:c`; chatbot
   modifies the haiku; ask Likert again.~~ ✅ **Done** — `Randomization.best_run/1` picks
   the writing run with the highest Likert average (random tie-break; flashes `"picked
   randomly"` in the frontend). `PingPong.respond_modification/3` calls the LLM with a
   variant-specific prompt (`modification_prompt/2`; injectable responder for tests via
   `:study_modification_responder` app env). `StudySessionLive` creates the `kind:
   :modification` run (fields `variant`, `source_run_index`, `original_haiku`,
   `modified_haiku`, `completed_at` set at creation) on the explicit "Weiter" click after
   the transition card — never on mount, so reloads do not trigger a second LLM call.
   `StudyComponents.modification_panel/1` shows both haiku versions + variant label.
7. ~~**End screen** — show `session_id` (UUID) for return to the originating tool; mark
   session `:completed`.~~ ✅ **Done** — `Session :complete` action (+ `Study.complete_session!/1`
   code interface) sets `status: :completed` and stamps `completed_at`. Called in
   `StudySessionLive.advance_run` after the modification run's Likert is submitted. The
   `:all_done` render branch shows the session UUID in a selectable mono block.
8. ~~**Export** — read action loading `session` + `runs`, serialized to JSON.~~ ✅ **Done**

## Open questions (to clarify before implementation)

1. ~~**"Best" run for run 5**: highest Likert average, all items positively coded (clarified).
   Open only: **tie-break** on equal scores (e.g. random, or a preferred
   `topic_source`/`ai_mode`).~~ **Resolved** — tie-break is random; frontend flashes
   `"picked randomly"` when multiple runs share the max average.
2. ~~**Modification variant distribution**: are `:a/:b/:c` drawn uniformly at random, or
   balanced (e.g. against the best run's `topic_source`/`ai_mode`)?~~ **Resolved** —
   drawn uniformly at random (`Enum.random([:a, :b, :c])`).

3. **Topic prompt**: Fixed topic pool, drawn at random, or configured per study?
4. **Ping-pong**: Fixed number of rounds? Who starts (user or AI)? When does a run end?
5. **Likert questionnaire**: Which concrete items, which scale (e.g. 5- or 7-point)? Same
   items across all five runs?
6. **`case_id` security**: lean first pass treats the link value as the `case_id` verbatim
   and rejects only blank/missing (redirect to `/`). Open: signature/expiry/single-use
   validation.
7. **Persistence**: resolved — store relationally via AshPostgres (`session` `has_many`
   `run`); JSON is only an on-demand export artifact from a read action, not the storage
   format. Open only: export trigger/format details (single session vs. bulk, file vs.
   download endpoint).
8. **Re-entry**: resolved — same `case_id` **resumes** the existing session (upsert on the
   `unique_case_id` identity), so reloads/back-navigation don't strand the participant.
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
<!-- ash_postgres-start -->
## ash_postgres usage
_The PostgreSQL data layer for Ash Framework_

# Rules for working with AshPostgres

## Understanding AshPostgres

AshPostgres is the PostgreSQL data layer for Ash Framework. It's the most fully-featured Ash data layer and should be your default choice unless you have specific requirements for another data layer. Any PostgreSQL version higher than 13 is fully supported.

Remember that using AshPostgres provides a full-featured PostgreSQL data layer for your Ash application, giving you both the structure and declarative approach of Ash along with the power and flexibility of PostgreSQL.

<!-- ash_postgres-end -->
<!-- ash_postgres:advanced_features-start -->
## ash_postgres:advanced_features usage
# Advanced Features

## Manual Relationships

For complex relationships that can't be expressed with standard relationship types:

```elixir
defmodule MyApp.Post.Relationships.HighlyRatedComments do
  use Ash.Resource.ManualRelationship
  use AshPostgres.ManualRelationship

  def load(posts, _opts, context) do
    post_ids = Enum.map(posts, & &1.id)

    {:ok,
     MyApp.Comment
     |> Ash.Query.filter(post_id in ^post_ids)
     |> Ash.Query.filter(rating > 4)
     |> MyApp.read!()
     |> Enum.group_by(& &1.post_id)}
  end

  def ash_postgres_join(query, _opts, current_binding, as_binding, :inner, destination_query) do
    {:ok,
     Ecto.Query.from(_ in query,
       join: dest in ^destination_query,
       as: ^as_binding,
       on: dest.post_id == as(^current_binding).id,
       on: dest.rating > 4
     )}
  end

  # Other required callbacks...
end

# In your resource:
relationships do
  has_many :highly_rated_comments, MyApp.Comment do
    manual MyApp.Post.Relationships.HighlyRatedComments
  end
end
```

## Using Multiple Repos (Read Replicas)

Configure different repos for reads vs mutations:

```elixir
postgres do
  repo fn resource, type ->
    case type do
      :read -> MyApp.ReadReplicaRepo
      :mutate -> MyApp.WriteRepo
    end
  end
end
```
<!-- ash_postgres:advanced_features-end -->
<!-- ash_postgres:best_practices-start -->
## ash_postgres:best_practices usage
# Best Practices

1. **Organize migrations**: Run `mix ash.codegen` after each meaningful set of resource changes with a descriptive name:
   ```bash
   mix ash.codegen --name add_user_roles
   mix ash.codegen --name implement_post_tagging
   ```

2. **Use check constraints for domain invariants**: Enforce data integrity at the database level:
   ```elixir
   check_constraints do
     check_constraint :valid_status, check: "status IN ('pending', 'active', 'completed')"
     check_constraint :positive_balance, check: "balance >= 0"
   end
   ```

3. **Use custom statements for schema-only changes**: If you need to add database objects not directly tied to resources:
   ```elixir
   custom_statements do
     statement "CREATE EXTENSION IF NOT EXISTS \"pgcrypto\""
     statement "CREATE INDEX users_search_idx ON users USING gin(search_vector)"
   end
   ```
<!-- ash_postgres:best_practices-end -->
<!-- ash_postgres:check_constraints-start -->
## ash_postgres:check_constraints usage
# Check Constraints

Define database check constraints:

```elixir
postgres do
  check_constraints do
    check_constraint :positive_amount,
      check: "amount > 0",
      name: "positive_amount_check",
      message: "Amount must be positive"

    check_constraint :status_valid,
      check: "status IN ('pending', 'active', 'completed')"
  end
end
```
<!-- ash_postgres:check_constraints-end -->
<!-- ash_postgres:configuration-start -->
## ash_postgres:configuration usage
# Basic Configuration

To use AshPostgres, add the data layer to your resource:

```elixir
defmodule MyApp.Tweet do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  attributes do
    integer_primary_key :id
    attribute :text, :string
  end

  relationships do
    belongs_to :author, MyApp.User
  end

  postgres do
    table "tweets"
    repo MyApp.Repo
  end
end
```

# PostgreSQL Configuration

## Table & Schema Configuration

```elixir
postgres do
  # Required: Define the table name for this resource
  table "users"

  # Optional: Define the PostgreSQL schema
  schema "public"

  # Required: Define the Ecto repo to use
  repo MyApp.Repo

  # Optional: Control whether migrations are generated for this resource
  migrate? true
end
```

<!-- ash_postgres:configuration-end -->
<!-- ash_postgres:custom_indexes-start -->
## ash_postgres:custom_indexes usage
# Custom Indexes

Define custom indexes beyond those automatically created for identities and relationships:

```elixir
postgres do
  custom_indexes do
    index [:first_name, :last_name]

    index :email,
      unique: true,
      name: "users_email_index",
      where: "email IS NOT NULL",
      using: :gin

    index [:status, :created_at],
      concurrently: true,
      include: [:user_id]
  end
end
```
<!-- ash_postgres:custom_indexes-end -->
<!-- ash_postgres:custom_sql_statements-start -->
## ash_postgres:custom_sql_statements usage
# Custom SQL Statements

Include custom SQL in migrations:

```elixir
postgres do
  custom_statements do
    statement "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\""

    statement """
    CREATE TRIGGER update_updated_at
    BEFORE UPDATE ON posts
    FOR EACH ROW
    EXECUTE FUNCTION trigger_set_timestamp();
    """

    statement "DROP INDEX IF EXISTS posts_title_index",
      on_destroy: true # Only run when resource is destroyed/dropped
  end
end
```
<!-- ash_postgres:custom_sql_statements-end -->
<!-- ash_postgres:foreign_keys-start -->
## ash_postgres:foreign_keys usage
# Foreign Key References

Use the `references` section to configure foreign key behavior:

```elixir
postgres do
  table "comments"
  repo MyApp.Repo

  references do
    # Simple reference with defaults
    reference :post

    # Fully configured reference
    reference :user,
      on_delete: :delete,      # What happens when referenced row is deleted
      on_update: :update,      # What happens when referenced row is updated
      name: "comments_to_users_fkey", # Custom constraint name
      deferrable: true,        # Make constraint deferrable
      initially_deferred: false # Defer constraint check to end of transaction
  end
end
```

## Foreign Key Actions

For `on_delete` and `on_update` options:

- `:nothing` or `:restrict` - Prevent the change to the referenced row
- `:delete` - Delete the row when the referenced row is deleted (for `on_delete` only)
- `:update` - Update the row according to changes in the referenced row (for `on_update` only)
- `:nilify` - Set all foreign key columns to NULL
- `{:nilify, columns}` - Set specific columns to NULL (Postgres 15.0+ only)

> **Warning**: These operations happen directly at the database level. No resource logic, authorization rules, validations, or notifications are triggered.
<!-- ash_postgres:foreign_keys-end -->
<!-- ash_postgres:migrations-start -->
## ash_postgres:migrations usage
# Migrations and Codegen

## Development Migration Workflow (Recommended)

For development iterations, use the dev workflow to avoid naming migrations prematurely:

1. Make resource changes
2. Run `mix ash.codegen --dev` to generate and run dev migrations
3. Review the migrations and run `mix ash.migrate` to run them
4. Continue making changes and running `mix ash.codegen --dev` as needed
5. When your feature is complete, run `mix ash.codegen add_feature_name` to generate final named migrations (this will rollback dev migrations and squash them)
3. Review the migrations and run `mix ash.migrate` to run them

## Traditional Migration Generation

For single-step changes or when you know the final feature name:

1. Run `mix ash.codegen add_feature_name` to generate migrations
2. Review the generated migrations in `priv/repo/migrations`
3. Run `mix ash.migrate` to apply the migrations

> **Tip**: The dev workflow (`--dev` flag) is preferred during development as it allows you to iterate without thinking of migration names and provides better development ergonomics.

> **Warning**: Always review migrations before applying them to ensure they are correct and safe.
<!-- ash_postgres:migrations-end -->
<!-- ash_postgres:multitenancy-start -->
## ash_postgres:multitenancy usage
# Multitenancy

AshPostgres supports schema-based multitenancy:

```elixir
defmodule MyApp.Tenant do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  # Resource definition...

  postgres do
    table "tenants"
    repo MyApp.Repo

    # Automatically create/manage tenant schemas
    manage_tenant do
      template ["tenant_", :id]
    end
  end
end
```

## Setting Up Multitenancy

1. Configure your repo to support multitenancy:

```elixir
defmodule MyApp.Repo do
  use AshPostgres.Repo, otp_app: :my_app

  # Return all tenant schemas for migrations
  def all_tenants do
    import Ecto.Query, only: [from: 2]
    all(from(t in "tenants", select: fragment("? || ?", "tenant_", t.id)))
  end
end
```

2. Mark resources that should be multi-tenant:

```elixir
defmodule MyApp.Post do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  multitenancy do
    strategy :context
    attribute :tenant
  end

  # Resource definition...
end
```

3. When tenant migrations are generated, they'll be in `priv/repo/tenant_migrations`

4. Run tenant migrations in addition to regular migrations:

```bash
# Run regular migrations
mix ash.migrate

# Run tenant migrations
mix ash_postgres.migrate --tenants
```
<!-- ash_postgres:multitenancy-end -->
<!-- ash_ai-start -->
## ash_ai usage
_Integrated LLM features for your Ash application._

# Rules for working with Ash AI

## Understanding Ash AI

Ash AI is an extension for the Ash framework that integrates AI capabilities with Ash resources. It provides tools for vectorization, embedding generation, LLM interaction, and tooling for AI models.

## Core Concepts

- **Vectorization**: Convert text attributes into vector embeddings for semantic search
- **AI Tools**: Expose Ash actions as tools for LLMs
- **Prompt-backed Actions**: Create actions where the implementation is handled by an LLM
- **MCP Server**: Expose your tools to Machine Context Protocol clients

## Vectorization

Vectorization allows you to convert text data into embeddings that can be used for semantic search.

### Setting Up Vectorization

Add vectorization to a resource by including the `AshAi` extension and defining a vectorize block:

```elixir
defmodule MyApp.Artist do
  use Ash.Resource, extensions: [AshAi]

  vectorize do
    # For creating a single vector from multiple attributes
    full_text do
      text(fn record ->
        """
        Name: #{record.name}
        Biography: #{record.biography}
        """
      end)

      # Optional - only rebuild embeddings when these attributes change
      used_attributes [:name, :biography]
    end

    # Choose a strategy for updating embeddings
    strategy :ash_oban

    # Specify your embedding model implementation
    embedding_model MyApp.OpenAiEmbeddingModel
  end

  # Rest of resource definition...
end
```

### Embedding Models

Create a module that implements the `AshAi.EmbeddingModel` behaviour to generate embeddings:

```elixir
defmodule MyApp.OpenAiEmbeddingModel do
  use AshAi.EmbeddingModel

  @impl true
  def dimensions(_opts), do: 3072

  @impl true
  def generate(texts, _opts) do
    api_key = System.fetch_env!("OPEN_AI_API_KEY")

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]

    body = %{
      "input" => texts,
      "model" => "text-embedding-3-large"
    }

    response =
      Req.post!("https://api.openai.com/v1/embeddings",
        json: body,
        headers: headers
      )

    case response.status do
      200 ->
        response.body["data"]
        |> Enum.map(fn %{"embedding" => embedding} -> embedding end)
        |> then(&{:ok, &1})

      _status ->
        {:error, response.body}
    end
  end
end
```

### Vectorization Strategies

Choose the appropriate strategy based on your performance requirements:

1. **`:after_action`** (default): Updates embeddings synchronously after each create and update action
   - Simple but can make your app slow
   - Not recommended for production use with many records

2. **`:ash_oban`**: Updates embeddings asynchronously using Ash Oban
   - Requires `ash_oban` extension
   - Better for production use

3. **`:manual`**: No automatic updates; you control when embeddings are updated
   - Most flexible but requires you to manage when to update embeddings

### Using the Vectors for Search

Use vector expressions in filters and sorts:

```elixir
read :semantic_search do
  argument :query, :string, allow_nil?: false

  prepare before_action(fn query, context ->
    case MyApp.OpenAiEmbeddingModel.generate([query.arguments.query], []) do
      {:ok, [search_vector]} ->
        Ash.Query.filter(
          query,
          vector_cosine_distance(full_text_vector, ^search_vector) < 0.5
        )
        |> Ash.Query.sort([
          {
              calc(vector_cosine_distance(
                full_text_vector,
                ^search_vector
              )),
            :asc
          }
        ])

      {:error, error} ->
        {:error, error}
    end
  end)
end
```

### Authorization for Vectorization

If you're using policies, add a bypass to allow embedding updates:

```elixir
bypass action(:ash_ai_update_embeddings) do
  authorize_if AshAi.Checks.ActorIsAshAi
end
```

## AI Tools

Expose your Ash actions as tools for LLMs to use by configuring them in your domain:

```elixir
defmodule MyApp.Blog do
  use Ash.Domain, extensions: [AshAi]

  tools do
    tool :read_posts, MyApp.Blog.Post, :read do
      description "customize the tool description"
    end
    tool :create_post, MyApp.Blog.Post, :create
    tool :publish_post, MyApp.Blog.Post, :publish
    tool :read_comments, MyApp.Blog.Comment, :read
  end

  # Rest of domain definition...
end
```

### Tool Data Access Rules

Tools have different access levels for different operations:

1. **Filtering/Sorting/Aggregation**: Only attributes with `public?: true` can be used
2. **Arguments**: Only action arguments with `public?: true` are exposed to tools
3. **Response data**: Public attributes are returned by default
4. **Loading data**: The `load` option is used to include relationships, calculations, or additional attributes in responses (both public and private)

Example:

```elixir
# Resource definition
defmodule MyApp.Blog.Post do
  attributes do
    attribute :title, :string, public?: true
    attribute :content, :string, public?: true
    attribute :internal_notes, :string  # Default is public?: false
    attribute :view_count, :integer, public?: true
  end
  
  relationships do
    belongs_to :author, MyApp.Accounts.User, public?: true
  end
end

# Tool definition
tools do
  # Returns only public attributes (title, content, view_count)
  tool :read_posts, MyApp.Blog.Post, :read
  
  # Returns public attributes plus loaded fields (including private ones)
  tool :read_posts_with_all_details, MyApp.Blog.Post, :read do
    load [:author, :internal_notes]
  end
end
```

With this configuration:
- Tools can only filter/sort by `title`, `content`, and `view_count`
- `internal_notes` cannot be used for filtering, sorting, or aggregation
- `internal_notes` CAN be returned when explicitly loaded via the `load` option
- The `author` relationship can include both public and private attributes when loaded

This provides flexibility while maintaining control over data access:
- Private data is protected from queries and operations
- Private data can still be included in responses when explicitly loaded
- The `load` option serves dual purposes: loading relationships/calculations and making any loaded attributes visible (including private ones)

### Using Tools in LangChain

Add your Ash AI tools to a LangChain chain:

```elixir
chain =
  %{
    llm: LangChain.ChatModels.ChatOpenAI.new!(%{model: "gpt-4o"}),
    verbose: true
  }
  |> LangChain.Chains.LLMChain.new!()
  |> AshAi.setup_ash_ai(otp_app: :my_app, tools: [:list, :of, :tools])
```

## Structured Outputs (Prompt-Backed Actions)

Create actions that use LLMs for their implementation:

```elixir
action :analyze_sentiment, :atom do
  constraints one_of: [:positive, :negative]

  description """
  Analyzes the sentiment of a given piece of text to determine if it is overall positive or negative.
  """

  argument :text, :string do
    allow_nil? false
    description "The text for analysis"
  end

  run prompt(
    LangChain.ChatModels.ChatOpenAI.new!(%{model: "gpt-4o"}),
    # Allow the model to use tools
    tools: true,
    # Or restrict to specific tools
    # tools: [:list, :of, :tool, :names],
    # Optionally provide a custom prompt template
    # prompt: "Analyze the sentiment of the following text: <%= @input.arguments.text %>"
  )
end
```

### Structured Outputs with Custom Types

The action's return type provides the JSON schema automatically. For complex structured outputs, you can use any Ash type, including `Ash.TypedStruct`:

```elixir
# Example using Ash.TypedStruct
defmodule JobListing do
  use Ash.TypedStruct

  typed_struct do
    field :title, :string, allow_nil?: false
    field :company, :string, allow_nil?: false
    field :location, :string
    field :salary_range, :string
    field :requirements, {:array, :string}
  end
end

# Use it as the return type for your action
action :parse_raw, JobListing do
  argument :raw_content, :string, allow_nil?: false

  run prompt(
    fn _input, _context ->
      LangChain.ChatModels.ChatOpenAI.new!(%{
        model: "gpt-4o-mini",
        api_key: System.get_env("OPENAI_API_KEY"),
        temperature: 0.1
      })
    end,
    prompt: """
    Parse this job listing into structured data following the exact schema.
    Extract all available information and return as JSON:

    <%= @input.arguments.raw_content %>
    """,
    tools: false
  )
end
```

### Dynamic LLM Configuration

For runtime configuration (like environment variables), use a function to define the LLM:

```elixir
action :analyze_sentiment, :atom do
  argument :text, :string, allow_nil?: false

  run prompt(
    fn _input, _context ->
      LangChain.ChatModels.ChatOpenAI.new!(%{
        model: "gpt-4o",
        # this can also be configured in application config, see langchain docs for more.
        api_key: System.get_env("OPENAI_API_KEY"),
        endpoint: System.get_env("OPENAI_ENDPOINT")
      })
    end,
    tools: false
  )
end
```

The function receives:
1. `input` - The action input
2. `context` - The execution context

### Prompt Format Options

The `prompt` option supports multiple formats for maximum flexibility:

#### 1. String (EEx Template)
Simple string templates with access to `@input` and `@context`:

```elixir
run prompt(
  ChatOpenAI.new!(%{model: "gpt-4o"}),
  prompt: "Analyze the sentiment of: <%= @input.arguments.text %>"
)
```

#### 2. System/User Tuple
Separate system and user messages (both support EEx templates):

```elixir
run prompt(
  ChatOpenAI.new!(%{model: "gpt-4o"}),
  prompt: {"You are a sentiment analyzer", "Analyze: <%= @input.arguments.text %>"}
)
```

#### 3. LangChain Messages List
For complex multi-turn conversations or image analysis:

```elixir
run prompt(
  ChatOpenAI.new!(%{model: "gpt-4o"}),
  prompt: [
    Message.new_system!("You are an expert assistant"),
    Message.new_user!("Hello, how can you help me?"),
    Message.new_assistant!("I can help with various tasks"),
    Message.new_user!("Great! Please analyze this data")
  ]
)
```

For image analysis with templates:

```elixir
run prompt(
  ChatOpenAI.new!(%{model: "gpt-4o"}),
  prompt: [
    Message.new_system!("You are an expert at image analysis"),
    Message.new_user!([
      PromptTemplate.from_template!("Extra context: <%= @input.arguments.context %>"),
      ContentPart.image!("<%= @input.arguments.image_data %>", media: :jpg, detail: "low")
    ])
  ]
)
```

#### 4. Dynamic Function
Return any of the above formats dynamically based on input:

```elixir
run prompt(
  ChatOpenAI.new!(%{model: "gpt-4o"}),
  prompt: fn input, context ->
    base = [Message.new_system!("You are helpful")]

    history = input.arguments.conversation_history
    |> Enum.map(fn %{"role" => role, "content" => content} ->
      case role do
        "user" -> Message.new_user!(content)
        "assistant" -> Message.new_assistant!(content)
      end
    end)

    base ++ history
  end
)
```

#### Template Processing

- **String prompts**: Processed as EEx templates with `@input` and `@context` variables
- **Messages with PromptTemplate**: Processed using LangChain's `apply_prompt_templates`
- **Functions**: Can return any supported format for dynamic generation

If no custom prompt is provided, a default template is used that includes the action name, description, and argument details.

### Adapters

Adapters control how the LLM is called to generate structured outputs. AshAi automatically selects the appropriate adapter based on your LLM, but you can override this with the `:adapter` option.

#### Default Adapter Selection

- **OpenAI API endpoints**: Uses `AshAi.Actions.Prompt.Adapter.StructuredOutput` (leverages OpenAI's structured output features)
- **Non-OpenAI endpoints**: Uses `AshAi.Actions.Prompt.Adapter.RequestJson` (requests JSON in the prompt)
- **Anthropic**: Uses `AshAi.Actions.Prompt.Adapter.CompletionTool` (uses tool calling for structured outputs)

#### Custom Adapter Configuration

You can specify a custom adapter or adapter options:

```elixir
# Use a specific adapter
run prompt(
  ChatOpenAI.new!(%{model: "gpt-4o"}),
  adapter: AshAi.Actions.Prompt.Adapter.RequestJson,
  tools: false
)

# Use an adapter with custom options
run prompt(
  ChatOpenAI.new!(%{model: "gpt-4o"}),
  adapter: {AshAi.Actions.Prompt.Adapter.StructuredOutput, [some_option: :value]},
  tools: false
)
```

#### Available Adapters

- **`StructuredOutput`**: Best for OpenAI models, uses native structured output capabilities
- **`RequestJson`**: Works with any model, requests JSON format in the prompt
- **`CompletionTool`**: Uses tool calling to generate structured outputs, good for models that support function calling

### Best Practices for Prompt-Backed Actions

- Write clear, detailed descriptions for the action and its arguments
- Use constraints when appropriate to restrict outputs
- Choose the appropriate prompt format for your use case:
  - Simple string templates for basic prompts
  - System/user tuples for role-based interactions
  - Message lists for complex conversations or multi-modal inputs
  - Functions for dynamic prompt generation
- Test thoroughly with different inputs to ensure reliable results

## Model Context Protocol (MCP) Server

### Development MCP Server

For development environments, add the dev MCP server to your Phoenix endpoint:

```elixir
if code_reloading? do
  socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket

  plug AshAi.Mcp.Dev,
    protocol_version_statement: "2024-11-05",
    otp_app: :your_app

  plug Phoenix.LiveReloader
  plug Phoenix.CodeReloader
end
```

### Production MCP Server

For production environments, set up authentication and add the MCP router:

```elixir
# Add api_key strategy to your auth pipeline
pipeline :mcp do
  plug AshAuthentication.Strategy.ApiKey.Plug,
    resource: YourApp.Accounts.User,
    required?: false  # Set to true if all tools require authentication
end

# In your router
scope "/mcp" do
  pipe_through :mcp

  forward "/", AshAi.Mcp.Router,
    tools: [
      # List your tools here
      :read_posts,
      :create_post,
      :analyze_sentiment
    ],
    protocol_version_statement: "2024-11-05",
    otp_app: :my_app
end
```

## Testing

When testing AI components:
- Mock embedding model responses for consistent test results
- Test vector search with known embeddings
- For prompt-backed actions, consider using deterministic test models
- Verify tool access and permissions work as expected

<!-- ash_ai-end -->
<!-- usage-rules-end -->
