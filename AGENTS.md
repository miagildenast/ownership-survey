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

<!-- phoenix:elixir-start -->
## Elixir guidelines

- Elixir lists **do not support index based access via the access syntax**

  **Never do this (invalid)**:

      i = 0
      mylist = ["blue", "green"]
      mylist[i]

  Instead, **always** use `Enum.at`, pattern matching, or `List` for index based list access, ie:

      i = 0
      mylist = ["blue", "green"]
      Enum.at(mylist, i)

- Elixir variables are immutable, but can be rebound, so for block expressions like `if`, `case`, `cond`, etc
  you *must* bind the result of the expression to a variable if you want to use it and you CANNOT rebind the result inside the expression, ie:

      # INVALID: we are rebinding inside the `if` and the result never gets assigned
      if connected?(socket) do
        socket = assign(socket, :val, val)
      end

      # VALID: we rebind the result of the `if` to a new variable
      socket =
        if connected?(socket) do
          assign(socket, :val, val)
        end

- **Never** nest multiple modules in the same file as it can cause cyclic dependencies and compilation errors
- **Never** use map access syntax (`changeset[:field]`) on structs as they do not implement the Access behaviour by default. For regular structs, you **must** access the fields directly, such as `my_struct.field` or use higher level APIs that are available on the struct if they exist, `Ecto.Changeset.get_field/2` for changesets
- Elixir's standard library has everything necessary for date and time manipulation. Familiarize yourself with the common `Time`, `Date`, `DateTime`, and `Calendar` interfaces by accessing their documentation as necessary. **Never** install additional dependencies unless asked or for date/time parsing (which you can use the `date_time_parser` package)
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Predicate function names should not start with `is_` and should end in a question mark. Names like `is_thing` should be reserved for guards
- Elixir's builtin OTP primitives like `DynamicSupervisor` and `Registry`, require names in the child spec, such as `{DynamicSupervisor, name: MyApp.MyDynamicSup}`, then you can use `DynamicSupervisor.start_child(MyApp.MyDynamicSup, child_spec)`
- Use `Task.async_stream(collection, callback, options)` for concurrent enumeration with back-pressure. The majority of times you will want to pass `timeout: :infinity` as option

## Mix guidelines

- Read the docs and options before using tasks (by using `mix help task_name`)
- To debug test failures, run tests in a specific file with `mix test test/my_test.exs` or run all previously failed tests with `mix test --failed`
- `mix deps.clean --all` is **almost never needed**. **Avoid** using it unless you have good reason

## Test guidelines

- **Always use `start_supervised!/1`** to start processes in tests as it guarantees cleanup between tests
- **Avoid** `Process.sleep/1` and `Process.alive?/1` in tests
  - Instead of sleeping to wait for a process to finish, **always** use `Process.monitor/1` and assert on the DOWN message:

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}

   - Instead of sleeping to synchronize before the next call, **always** use `_ = :sys.get_state/1` to ensure the process has handled prior messages
<!-- phoenix:elixir-end -->

<!-- phoenix:phoenix-start -->
## Phoenix guidelines

- Remember Phoenix router `scope` blocks include an optional alias which is prefixed for all routes within the scope. **Always** be mindful of this when creating routes within a scope to avoid duplicate module prefixes.

- You **never** need to create your own `alias` for route definitions! The `scope` provides the alias, ie:

      scope "/admin", AppWeb.Admin do
        pipe_through :browser

        live "/users", UserLive, :index
      end

  the UserLive route would point to the `AppWeb.Admin.UserLive` module

- `Phoenix.View` no longer is needed or included with Phoenix, don't use it
<!-- phoenix:phoenix-end -->


<!-- phoenix:html-start -->
## Phoenix HTML guidelines

- Phoenix templates **always** use `~H` or .html.heex files (known as HEEx), **never** use `~E`
- **Always** use the imported `Phoenix.Component.form/1` and `Phoenix.Component.inputs_for/1` function to build forms. **Never** use `Phoenix.HTML.form_for` or `Phoenix.HTML.inputs_for` as they are outdated
- When building forms **always** use the already imported `Phoenix.Component.to_form/2` (`assign(socket, form: to_form(...))` and `<.form for={@form} id="msg-form">`), then access those forms in the template via `@form[:field]`
- **Always** add unique DOM IDs to key elements (like forms, buttons, etc) when writing templates, these IDs can later be used in tests (`<.form for={@form} id="product-form">`)
- For "app wide" template imports, you can import/alias into the `my_app_web.ex`'s `html_helpers` block, so they will be available to all LiveViews, LiveComponent's, and all modules that do `use MyAppWeb, :html` (replace "my_app" by the actual app name)

- Elixir supports `if/else` but **does NOT support `if/else if` or `if/elsif`**. **Never use `else if` or `elseif` in Elixir**, **always** use `cond` or `case` for multiple conditionals.

  **Never do this (invalid)**:

      <%= if condition do %>
        ...
      <% else if other_condition %>
        ...
      <% end %>

  Instead **always** do this:

      <%= cond do %>
        <% condition -> %>
          ...
        <% condition2 -> %>
          ...
        <% true -> %>
          ...
      <% end %>

- HEEx require special tag annotation if you want to insert literal curly's like `{` or `}`. If you want to show a textual code snippet on the page in a `<pre>` or `<code>` block you *must* annotate the parent tag with `phx-no-curly-interpolation`:

      <code phx-no-curly-interpolation>
        let obj = {key: "val"}
      </code>

  Within `phx-no-curly-interpolation` annotated tags, you can use `{` and `}` without escaping them, and dynamic Elixir expressions can still be used with `<%= ... %>` syntax

- HEEx class attrs support lists, but you must **always** use list `[...]` syntax. You can use the class list syntax to conditionally add classes, **always do this for multiple class values**:

      <a class={[
        "px-2 text-white",
        @some_flag && "py-5",
        if(@other_condition, do: "border-red-500", else: "border-blue-100"),
        ...
      ]}>Text</a>

  and **always** wrap `if`'s inside `{...}` expressions with parens, like done above (`if(@other_condition, do: "...", else: "...")`)

  and **never** do this, since it's invalid (note the missing `[` and `]`):

      <a class={
        "px-2 text-white",
        @some_flag && "py-5"
      }> ...
      => Raises compile syntax error on invalid HEEx attr syntax

- **Never** use `<% Enum.each %>` or non-for comprehensions for generating template content, instead **always** use `<%= for item <- @collection do %>`
- HEEx HTML comments use `<%!-- comment --%>`. **Always** use the HEEx HTML comment syntax for template comments (`<%!-- comment --%>`)
- HEEx allows interpolation via `{...}` and `<%= ... %>`, but the `<%= %>` **only** works within tag bodies. **Always** use the `{...}` syntax for interpolation within tag attributes, and for interpolation of values within tag bodies. **Always** interpolate block constructs (if, cond, case, for) within tag bodies using `<%= ... %>`.

  **Always** do this:

      <div id={@id}>
        {@my_assign}
        <%= if @some_block_condition do %>
          {@another_assign}
        <% end %>
      </div>

  and **Never** do this – the program will terminate with a syntax error:

      <%!-- THIS IS INVALID NEVER EVER DO THIS --%>
      <div id="<%= @invalid_interpolation %>">
        {if @invalid_block_construct do}
        {end}
      </div>
<!-- phoenix:html-end -->

<!-- phoenix:liveview-start -->
## Phoenix LiveView guidelines

- **Never** use the deprecated `live_redirect` and `live_patch` functions, instead **always** use the `<.link navigate={href}>` and  `<.link patch={href}>` in templates, and `push_navigate` and `push_patch` functions LiveViews
- **Avoid LiveComponent's** unless you have a strong, specific need for them
- LiveViews should be named like `AppWeb.WeatherLive`, with a `Live` suffix. When you go to add LiveView routes to the router, the default `:browser` scope is **already aliased** with the `AppWeb` module, so you can just do `live "/weather", WeatherLive`

### LiveView streams

- **Always** use LiveView streams for collections for assigning regular lists to avoid memory ballooning and runtime termination with the following operations:
  - basic append of N items - `stream(socket, :messages, [new_msg])`
  - resetting stream with new items - `stream(socket, :messages, [new_msg], reset: true)` (e.g. for filtering items)
  - prepend to stream - `stream(socket, :messages, [new_msg], at: -1)`
  - deleting items - `stream_delete(socket, :messages, msg)`

- When using the `stream/3` interfaces in the LiveView, the LiveView template must 1) always set `phx-update="stream"` on the parent element, with a DOM id on the parent element like `id="messages"` and 2) consume the `@streams.stream_name` collection and use the id as the DOM id for each child. For a call like `stream(socket, :messages, [new_msg])` in the LiveView, the template would be:

      <div id="messages" phx-update="stream">
        <div :for={{id, msg} <- @streams.messages} id={id}>
          {msg.text}
        </div>
      </div>

- LiveView streams are *not* enumerable, so you cannot use `Enum.filter/2` or `Enum.reject/2` on them. Instead, if you want to filter, prune, or refresh a list of items on the UI, you **must refetch the data and re-stream the entire stream collection, passing reset: true**:

      def handle_event("filter", %{"filter" => filter}, socket) do
        # re-fetch the messages based on the filter
        messages = list_messages(filter)

        {:noreply,
         socket
         |> assign(:messages_empty?, messages == [])
         # reset the stream with the new messages
         |> stream(:messages, messages, reset: true)}
      end

- LiveView streams *do not support counting or empty states*. If you need to display a count, you must track it using a separate assign. For empty states, you can use Tailwind classes:

      <div id="tasks" phx-update="stream">
        <div class="hidden only:block">No tasks yet</div>
        <div :for={{id, task} <- @streams.tasks} id={id}>
          {task.name}
        </div>
      </div>

  The above only works if the empty state is the only HTML block alongside the stream for-comprehension.

- When updating an assign that should change content inside any streamed item(s), you MUST re-stream the items
  along with the updated assign:

      def handle_event("edit_message", %{"message_id" => message_id}, socket) do
        message = Chat.get_message!(message_id)
        edit_form = to_form(Chat.change_message(message, %{content: message.content}))

        # re-insert message so @editing_message_id toggle logic takes effect for that stream item
        {:noreply,
         socket
         |> stream_insert(:messages, message)
         |> assign(:editing_message_id, String.to_integer(message_id))
         |> assign(:edit_form, edit_form)}
      end

  And in the template:

      <div id="messages" phx-update="stream">
        <div :for={{id, message} <- @streams.messages} id={id} class="flex group">
          {message.username}
          <%= if @editing_message_id == message.id do %>
            <%!-- Edit mode --%>
            <.form for={@edit_form} id="edit-form-#{message.id}" phx-submit="save_edit">
              ...
            </.form>
          <% end %>
        </div>
      </div>

- **Never** use the deprecated `phx-update="append"` or `phx-update="prepend"` for collections

### LiveView JavaScript interop

- Remember anytime you use `phx-hook="MyHook"` and that JS hook manages its own DOM, you **must** also set the `phx-update="ignore"` attribute
- **Always** provide an unique DOM id alongside `phx-hook` otherwise a compiler error will be raised

LiveView hooks come in two flavors, 1) colocated js hooks for "inline" scripts defined inside HEEx,
and 2) external `phx-hook` annotations where JavaScript object literals are defined and passed to the `LiveSocket` constructor.

#### Inline colocated js hooks

**Never** write raw embedded `<script>` tags in heex as they are incompatible with LiveView.
Instead, **always use a colocated js hook script tag (`:type={Phoenix.LiveView.ColocatedHook}`)
when writing scripts inside the template**:

    <input type="text" name="user[phone_number]" id="user-phone-number" phx-hook=".PhoneNumber" />
    <script :type={Phoenix.LiveView.ColocatedHook} name=".PhoneNumber">
      export default {
        mounted() {
          this.el.addEventListener("input", e => {
            let match = this.el.value.replace(/\D/g, "").match(/^(\d{3})(\d{3})(\d{4})$/)
            if(match) {
              this.el.value = `${match[1]}-${match[2]}-${match[3]}`
            }
          })
        }
      }
    </script>

- colocated hooks are automatically integrated into the app.js bundle
- colocated hooks names **MUST ALWAYS** start with a `.` prefix, i.e. `.PhoneNumber`

#### External phx-hook

External JS hooks (`<div id="myhook" phx-hook="MyHook">`) must be placed in `assets/js/` and passed to the
LiveSocket constructor:

    const MyHook = {
      mounted() { ... }
    }
    let liveSocket = new LiveSocket("/live", Socket, {
      hooks: { MyHook }
    });

#### Pushing events between client and server

Use LiveView's `push_event/3` when you need to push events/data to the client for a phx-hook to handle.
**Always** return or rebind the socket on `push_event/3` when pushing events:

    # re-bind socket so we maintain event state to be pushed
    socket = push_event(socket, "my_event", %{...})

    # or return the modified socket directly:
    def handle_event("some_event", _, socket) do
      {:noreply, push_event(socket, "my_event", %{...})}
    end

Pushed events can then be picked up in a JS hook with `this.handleEvent`:

    mounted() {
      this.handleEvent("my_event", data => console.log("from server:", data));
    }

Clients can also push an event to the server and receive a reply with `this.pushEvent`:

    mounted() {
      this.el.addEventListener("click", e => {
        this.pushEvent("my_event", { one: 1 }, reply => console.log("got reply from server:", reply));
      })
    }

Where the server handled it via:

    def handle_event("my_event", %{"one" => 1}, socket) do
      {:reply, %{two: 2}, socket}
    end

### LiveView tests

- `Phoenix.LiveViewTest` module and `LazyHTML` (included) for making your assertions
- Form tests are driven by `Phoenix.LiveViewTest`'s `render_submit/2` and `render_change/2` functions
- Come up with a step-by-step test plan that splits major test cases into small, isolated files. You may start with simpler tests that verify content exists, gradually add interaction tests
- **Always reference the key element IDs you added in the LiveView templates in your tests** for `Phoenix.LiveViewTest` functions like `element/2`, `has_element/2`, selectors, etc
- **Never** tests again raw HTML, **always** use `element/2`, `has_element/2`, and similar: `assert has_element?(view, "#my-form")`
- Instead of relying on testing text content, which can change, favor testing for the presence of key elements
- Focus on testing outcomes rather than implementation details
- Be aware that `Phoenix.Component` functions like `<.form>` might produce different HTML than expected. Test against the output HTML structure, not your mental model of what you expect it to be
- When facing test failures with element selectors, add debug statements to print the actual HTML, but use `LazyHTML` selectors to limit the output, ie:

      html = render(view)
      document = LazyHTML.from_fragment(html)
      matches = LazyHTML.filter(document, "your-complex-selector")
      IO.inspect(matches, label: "Matches")
