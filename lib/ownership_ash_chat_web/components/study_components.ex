defmodule OwnershipAshChatWeb.StudyComponents do
  @moduledoc """
  Shared function components for the study writing flow. The `run_panel/1` block (topic
  form + transcript + passage form + assembled haiku) is reused by both the session-driven
  `StudySessionLive` (`/study`) and the dev single-run harness `StudyWritingLive`
  (`/dev/study/run/:run_id`).
  """
  use OwnershipAshChatWeb, :html

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
          <.input type="textarea" name="text" value="" label="Deine Zeile" />
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
end
