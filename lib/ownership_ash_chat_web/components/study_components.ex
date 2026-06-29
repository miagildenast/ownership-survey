defmodule OwnershipAshChatWeb.StudyComponents do
  @moduledoc """
  Shared function components for the study writing flow. The `run_panel/1` block (topic
  form + transcript + passage form + assembled haiku) is reused by both the session-driven
  `StudySessionLive` (`/study`) and the dev single-run harness `StudyWritingLive`
  (`/dev/study/run/:run_id`).
  """
  use OwnershipAshChatWeb, :html

  alias OwnershipAshChat.Study.Likert
  alias OwnershipAshChat.Study.PingPong

  @doc """
  Renders one run's writing UI.

  Assigns:
    * `:run` — the `Study.Run` record.
    * `:can_add_passage?` — whether the passage form is shown.
    * `:lines_done?` — whether the run holds its full set of lines.
  """
  attr :run, :map, required: true
  attr :can_add_passage?, :boolean, required: true
  attr :lines_done?, :boolean, required: true

  def run_panel(assigns) do
    ~H"""
    <div class="space-y-6">
      <section class="rounded-xl border border-base-300 p-4 space-y-3">
        <h2 class="font-medium">Thema</h2>
        <p :if={@run.topic} class="text-base-content/80">{@run.topic}</p>
        <.form
          :if={@run.topic_source == :free and is_nil(@run.topic)}
          for={%{}}
          id="topic-form"
          phx-submit="set_topic"
          class="flex gap-2 items-end"
        >
          <.input type="text" name="topic" value="" label="Thema wählen" />
          <.button>Speichern</.button>
        </.form>
        <p
          :if={@run.topic_source == :assigned and is_nil(@run.topic)}
          class="text-sm text-base-content/50"
        >
          Kein Thema gesetzt.
        </p>
      </section>

      <section class="rounded-xl border border-base-300 p-4 space-y-3">
        <h2 class="font-medium">Transkript</h2>
        <p :if={@run.transcript in [nil, []]} class="text-sm text-base-content/50">
          Noch keine Passagen.
        </p>
        <ul class="space-y-2">
          <li
            :for={passage <- @run.transcript || []}
            class={[
              "rounded-lg px-3 py-2 text-sm",
              passage_role(passage) == "ai" && "bg-base-200",
              passage_role(passage) == "user" && "bg-primary/10"
            ]}
          >
            <span class="font-mono text-xs uppercase text-base-content/50">
              {passage_role(passage)}
            </span>
            <div>{passage_text(passage)}</div>
          </li>
        </ul>

        <.form
          :if={@can_add_passage?}
          for={%{}}
          id="passage-form"
          phx-submit="add_passage"
          class="space-y-2"
        >
          <.input
            type="text"
            id={"passage-input-#{length(@run.transcript || [])}"}
            name="text"
            value=""
            label="Deine Zeile"
          />
          <.button>Senden</.button>
        </.form>
        <p :if={@lines_done?} class="text-sm text-base-content/60">
          Schreibphase abgeschlossen ({PingPong.lines()} Zeilen).
        </p>
      </section>

      <section class="rounded-xl border border-base-300 p-4 space-y-3">
        <h2 class="font-medium">Finales Haiku</h2>
        <p :if={is_nil(@run.final_haiku)} class="text-sm text-base-content/50">
          Wird nach der letzten Zeile automatisch zusammengesetzt.
        </p>
        <pre :if={@run.final_haiku} class="whitespace-pre-wrap text-base-content/80">{@run.final_haiku}</pre>
      </section>
    </div>
    """
  end

  defp passage_role(%{"role" => role}), do: role
  defp passage_role(%{role: role}), do: to_string(role)
  defp passage_role(_), do: nil

  defp passage_text(%{"text" => text}), do: text
  defp passage_text(%{text: text}), do: text
  defp passage_text(_), do: ""

  @doc """
  Renders the post-run Likert questionnaire (plan step #5).

  Shown once the run has auto-completed; submits via the `submit_likert` event and,
  once answered, shows the saved answers read-only. Reused by `StudySessionLive` and
  the dev harness `StudyWritingLive`.

  Assigns:
    * `:run` — the completed `Study.Run` record (carries `run.likert`).
  """
  attr :run, :map, required: true

  def likert_panel(assigns) do
    assigns =
      assigns
      |> assign(:likert_items, Likert.items())
      |> assign(:likert_options, likert_options())
      |> assign(:likert_submitted?, likert_submitted?(assigns.run))

    ~H"""
    <section class="rounded-xl border border-base-300 p-4 space-y-3">
      <h2 class="font-medium">Fragebogen</h2>

      <.form
        :if={not @likert_submitted?}
        for={%{}}
        id="likert-form"
        phx-submit="submit_likert"
        class="space-y-6"
      >
        <fieldset :for={item <- @likert_items} class="space-y-2">
          <legend class="text-sm font-medium text-base-content">{item.prompt}</legend>
          <div class="flex flex-col gap-2 sm:flex-row sm:flex-wrap sm:gap-4">
            <label
              :for={{label, value} <- @likert_options}
              class="flex items-center gap-2 cursor-pointer text-sm text-base-content/80 transition-colors hover:text-base-content"
            >
              <input
                type="radio"
                name={"likert[#{item.key}]"}
                value={value}
                checked={likert_value(@run, item.key) == value}
                class="radio radio-sm radio-primary"
                required
              />
              <span>{label}</span>
            </label>
          </div>
        </fieldset>
        <.button>Fragebogen absenden</.button>
      </.form>

      <div :if={@likert_submitted?} class="space-y-2">
        <p class="text-sm text-success">Fragebogen gespeichert.</p>
        <ul class="space-y-1 text-sm">
          <li :for={item <- @likert_items} class="flex justify-between gap-4">
            <span class="text-base-content/80">{item.prompt}</span>
            <span class="font-mono">{likert_value(@run, item.key)}</span>
          </li>
        </ul>
      </div>
    </section>
    """
  end

  @doc "Whether the run's questionnaire has been answered."
  def likert_submitted?(run), do: map_size(run.likert || %{}) > 0

  # `<.input type="select">` options as {label, value}, e.g. {"1 – Stimme gar nicht zu", "1"}.
  defp likert_options do
    Enum.map(Likert.scale(), fn value ->
      {"#{value} – #{Map.fetch!(Likert.scale_labels(), value)}", value}
    end)
  end

  defp likert_value(run, key), do: Map.get(run.likert || %{}, Atom.to_string(key))
end
