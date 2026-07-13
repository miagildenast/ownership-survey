defmodule OwnershipAshChatWeb.StudyComponents do
  @moduledoc """
  Shared function components for the study writing flow, reused by the
  session-driven `StudySessionLive` (`/study`) and the dev single-run harness
  `StudyWritingLive` (`/dev/study/run/:run_id`):

    * `chat_panel/1` — the ChatGPT-style writing window (bubbles, task messages,
      typing indicator, input row)
    * `instructions_panel/1` — the always-visible haiku instructions, with the
      Start button on the intro screen
    * `progress_bar/1` — the slim overall-progress bar
    * `likert_screen/1` — the full-screen post-run questionnaire with the haiku
  """
  use OwnershipAshChatWeb, :html

  alias OwnershipAshChat.Study.Likert
  alias OwnershipAshChat.Study.Run.Transcript
  alias OwnershipAshChatWeb.Markdown
  alias OwnershipAshChatWeb.StudyTexts

  @doc """
  Renders one run's writing UI as a chat window: transcript passages as message
  bubbles (participant right, AI left), the UI-only task messages (the current
  one highlighted, answered ones kept muted in the history), a typing indicator
  while the AI writes, and the text input pinned at the bottom.

  The form wraps the whole panel so the typing indicator can react to the
  submit-loading state (`phx-submit-loading:` variant needs the form as ancestor).

  Assigns:
    * `:run` — the `Study.Run` record.
    * `:can_add_passage?` — whether the passage form is shown.
    * `:pending_line` — an optimistically shown user line whose persistence (and
      AI reply) is still in flight; the input is inert while set.
    * `:disabled` — renders an inert preview (no form, no tasks, disabled input)
      for the intro screen.
  """
  attr :run, :map, required: true
  attr :can_add_passage?, :boolean, required: true
  attr :pending_line, :string, default: nil
  attr :disabled, :boolean, default: false

  def chat_panel(assigns) do
    assigns =
      assigns
      |> assign(:entries, chat_entries(assigns.run))
      |> assign(
        :current_task,
        if(assigns.disabled, do: nil, else: StudyTexts.task_message(assigns.run))
      )

    ~H"""
    <section class="flex h-full min-h-0 flex-col rounded-xl border border-base-300 bg-base-100">
      <.form
        :if={@can_add_passage? and not @disabled and is_nil(@pending_line)}
        for={%{}}
        id="passage-form"
        phx-submit="add_passage"
        class="flex min-h-0 flex-1 flex-col"
      >
        <.chat_messages
          entries={@entries}
          current_task={@current_task}
          run={@run}
          pending_line={@pending_line}
        />

        <div class="flex items-start gap-2 border-t border-base-300 p-3">
          <div class="flex-1">
            <.input
              type="text"
              id={"passage-input-#{length(@run.transcript || [])}"}
              name="text"
              value=""
              placeholder="Deine Zeile"
              autocomplete="off"
              required
              phx-mounted={JS.focus()}
            />
          </div>
          <.button phx-disable-with={
            if @run.ai_mode == :with_ai, do: "KI schreibt…", else: "Speichern…"
          }>
            Senden
          </.button>
        </div>
      </.form>

      <div
        :if={not @can_add_passage? or @disabled or not is_nil(@pending_line)}
        class="flex min-h-0 flex-1 flex-col"
      >
        <.chat_messages
          entries={@entries}
          current_task={@current_task}
          run={@run}
          pending_line={@pending_line}
        />

        <div class="flex items-start gap-2 border-t border-base-300 p-3">
          <div class="flex-1">
            <.input type="text" name="text-disabled" value="" placeholder="Deine Zeile" disabled />
          </div>
          <.button disabled>Senden</.button>
        </div>
      </div>
    </section>
    """
  end

  # The scrollable message list: history entries (passages + already-answered
  # task messages, muted), the current task (highlighted), the optimistically
  # shown pending user line, and the AI typing indicator while the reply is
  # being generated.
  attr :entries, :list, required: true
  attr :current_task, :string, default: nil
  attr :run, :map, required: true
  attr :pending_line, :string, default: nil

  defp chat_messages(assigns) do
    ~H"""
    <div
      id="chat-messages"
      phx-hook=".ChatScroll"
      class="min-h-32 flex-1 space-y-3 overflow-y-auto p-4"
    >
      <%= for entry <- @entries do %>
        <%= case entry do %>
          <% {:task, task} -> %>
            <div class="prose prose-sm dark:prose-invert max-w-[80%] mr-auto rounded-2xl rounded-bl-sm border border-base-300 bg-base-200/60 px-4 py-2 text-sm italic text-base-content/60">
              {Markdown.to_html(task)}
            </div>
          <% {:passage, passage} -> %>
            <div class={[
              "max-w-[80%] rounded-2xl px-4 py-2 text-sm",
              passage_role(passage) == "user" &&
                "ml-auto rounded-br-sm bg-primary text-primary-content",
              passage_role(passage) != "user" && "mr-auto rounded-bl-sm bg-base-200"
            ]}>
              <p>{passage_text(passage)}</p>
              <p :if={passage_candidates(passage)} class="mt-1 text-xs opacity-70">
                KI konnte nicht zuverlässig eine Zeile generieren, hier sind die
                ausprobierten Kandidaten: {Enum.join(passage_candidates(passage), ", ")}
              </p>
            </div>
        <% end %>
      <% end %>

      <div
        :if={@current_task}
        id={"task-message-#{length(@run.transcript || [])}"}
        class="prose prose-sm dark:prose-invert max-w-[80%] mr-auto rounded-2xl rounded-bl-sm border-2 border-orange-400 bg-base-200/60 px-4 py-2 text-sm text-base-content/80"
      >
        {Markdown.to_html(@current_task)}
      </div>

      <div
        :if={@pending_line}
        id="pending-line"
        class="ml-auto max-w-[80%] rounded-2xl rounded-br-sm bg-primary px-4 py-2 text-sm text-primary-content"
      >
        <p>{@pending_line}</p>
      </div>

      <div
        :if={@pending_line && ai_replying?(@run)}
        id="ai-typing"
        class="mr-auto flex max-w-[80%] items-center gap-1.5 rounded-2xl rounded-bl-sm bg-base-200 px-4 py-3"
      >
        <span class="size-2 animate-bounce rounded-full bg-base-content/40"></span>
        <span class="size-2 animate-bounce rounded-full bg-base-content/40 [animation-delay:150ms]"></span>
        <span class="size-2 animate-bounce rounded-full bg-base-content/40 [animation-delay:300ms]"></span>
      </div>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".ChatScroll">
      export default {
        mounted() {
          this.el.scrollTop = this.el.scrollHeight;
        },
        updated() {
          this.el.scrollTop = this.el.scrollHeight;
        }
      }
    </script>
    """
  end

  # Whether the AI will reply to the pending user line (its turn follows the
  # position the pending line will occupy).
  defp ai_replying?(run) do
    run.ai_mode == :with_ai and
      Transcript.ai_turn?(run, length(run.transcript || []) + 1)
  end

  # Interleave answered task messages before the passage they prompted, so the
  # chat history reads chronologically. AI positions yield no task.
  defp chat_entries(run) do
    (run.transcript || [])
    |> Enum.with_index()
    |> Enum.flat_map(fn {passage, position} ->
      case StudyTexts.task_message(run, position) do
        nil -> [{:passage, passage}]
        task -> [{:task, task}, {:passage, passage}]
      end
    end)
  end

  @doc """
  Renders the haiku instructions panel shown next to (desktop) or above (mobile)
  the chat during the whole writing phase. On the intro screen it additionally
  carries the big Start button.

  Assigns:
    * `:show_start` — whether the Start button is rendered (intro only).
  """
  attr :show_start, :boolean, default: false

  def instructions_panel(assigns) do
    ~H"""
    <section class={[
      "flex min-h-0 flex-col rounded-xl border border-base-300 md:max-h-none",
      if(@show_start, do: "max-h-[60dvh]", else: "max-h-[30dvh]")
    ]}>
      <div class="min-h-0 flex-1 overflow-y-auto p-4 md:p-6">
        <h1 class="text-xl font-semibold md:text-2xl">{StudyTexts.intro_heading()}</h1>
        <div class="prose prose-sm dark:prose-invert md:prose-base mt-3 max-w-none text-base-content/80 md:mt-4">
          {Markdown.to_html(StudyTexts.intro_text())}
        </div>
      </div>
      <div :if={@show_start} class="shrink-0 p-4 pt-0 md:p-6 md:pt-0">
        <.button
          id="start-btn"
          class="btn btn-primary btn-lg w-full"
          phx-click="start_study"
          phx-disable-with="Bitte warten…"
        >
          Start
        </.button>
      </div>
    </section>
    """
  end

  @doc """
  Renders the slim overall-progress bar with an optional label.

  Assigns:
    * `:percent` — 0..100.
    * `:label` — short progress label (e.g. "Run 2 von 4"), or `nil`.
  """
  attr :percent, :integer, required: true
  attr :label, :string, default: nil

  def progress_bar(assigns) do
    ~H"""
    <div class="flex items-center gap-3">
      <div class="h-1.5 flex-1 overflow-hidden rounded-full bg-base-300">
        <div
          class="h-full rounded-full bg-primary transition-[width] duration-500"
          style={"width: #{@percent}%"}
        >
        </div>
      </div>
      <span :if={@label} class="whitespace-nowrap text-xs text-base-content/60">{@label}</span>
    </div>
    """
  end

  @doc """
  Renders the full-screen post-run Likert questionnaire: the run's haiku (the
  modified version for the modification run), the "Fragebogen:" heading, the
  items, and a submit button that continues to the next task.

  Assigns:
    * `:run` — the completed `Study.Run` record.
  """
  attr :run, :map, required: true

  def likert_screen(assigns) do
    assigns =
      assigns
      |> assign(:haiku, likert_haiku(assigns.run))
      |> assign(:likert_items, Likert.items())
      |> assign(:likert_options, likert_options())
      |> assign(:open_questions, open_questions_for(assigns.run))

    ~H"""
    <.form for={%{}} id="likert-form" phx-submit="submit_likert" class="space-y-6">
      <section class="rounded-xl border border-base-300 p-4 md:p-6">
        <pre class="whitespace-pre-wrap text-center text-lg leading-relaxed">{@haiku}</pre>
      </section>

      <section class="rounded-xl border border-base-300 p-4 space-y-4 md:p-6">
        <h2 class="text-xl font-semibold">Fragebogen:</h2>

        <fieldset :for={{item, item_idx} <- Enum.with_index(@likert_items)} class="space-y-2">
          <legend class="prose prose-sm dark:prose-invert max-w-none text-sm font-medium text-base-content">
            {Markdown.to_html(item.prompt)}
          </legend>
          <div class="flex flex-col gap-2">
            <label
              :for={{{label, value}, opt_idx} <- Enum.with_index(@likert_options)}
              class="flex items-center gap-2 cursor-pointer text-sm text-base-content/80 transition-colors hover:text-base-content"
            >
              <input
                type="radio"
                name={"likert[#{item.key}]"}
                value={value}
                checked={likert_value(@run, item.key) == value}
                class="radio radio-sm radio-primary"
                required
                phx-mounted={if item_idx == 0 and opt_idx == 0, do: JS.focus()}
              />
              <span>{label}</span>
            </label>
          </div>
        </fieldset>
      </section>

      <section
        :if={@open_questions != []}
        class="rounded-xl border border-base-300 p-4 space-y-4 md:p-6"
      >
        <div :for={question <- @open_questions} class="space-y-2">
          <label
            for={"open-#{question.key}"}
            class="prose prose-sm dark:prose-invert block max-w-none text-sm font-medium text-base-content"
          >
            {Markdown.to_html(question.prompt)}
          </label>
          <textarea
            id={"open-#{question.key}"}
            name={"open_answers[#{question.key}]"}
            rows="4"
            required
            class="textarea textarea-bordered w-full"
          >{open_value(@run, question.key)}</textarea>
        </div>
      </section>

      <div class="sticky bottom-0 -mx-4 -mb-6 border-t border-base-300 bg-base-100/95 px-4 py-3 backdrop-blur sm:-mb-10 sm:mx-0 sm:rounded-t-xl sm:px-3">
        <div class="flex sm:justify-end">
          <.button class="btn btn-primary w-full sm:w-auto" phx-disable-with="Bitte warten…">
            Weiter
          </.button>
        </div>
      </div>
    </.form>
    """
  end

  defp likert_haiku(%{kind: :modification} = run), do: run.modified_haiku
  defp likert_haiku(run), do: run.final_haiku

  # Open-ended questions are asked only on the modification run.
  defp open_questions_for(%{kind: :modification}), do: Likert.open_questions()
  defp open_questions_for(_run), do: []

  defp open_value(run, key), do: Map.get(run.open_answers || %{}, Atom.to_string(key))

  defp passage_role(%{"role" => role}), do: role
  defp passage_role(%{role: role}), do: to_string(role)
  defp passage_role(_), do: nil

  defp passage_text(%{"text" => text}), do: text
  defp passage_text(%{text: text}), do: text
  defp passage_text(_), do: ""

  # Non-empty candidate list only for AI passages flagged as fallbacks; nil otherwise.
  defp passage_candidates(%{"fallback" => true, "candidates" => [_ | _] = candidates}),
    do: candidates

  defp passage_candidates(_), do: nil

  @doc "Whether the run's questionnaire has been answered."
  def likert_submitted?(run), do: map_size(run.likert || %{}) > 0

  # Radio options as {label, value}, e.g. {"1 – Stimme gar nicht zu", "1"}.
  defp likert_options do
    Enum.map(Likert.scale(), fn value ->
      {"#{value} – #{Map.fetch!(Likert.scale_labels(), value)}", value}
    end)
  end

  defp likert_value(run, key), do: Map.get(run.likert || %{}, Atom.to_string(key))
end
