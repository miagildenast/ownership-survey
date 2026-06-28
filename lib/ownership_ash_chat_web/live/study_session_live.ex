defmodule OwnershipAshChatWeb.StudySessionLive do
  @moduledoc """
  Session-driven study flow (AGENTS.md plan step #3, flow part). Reads the `session_id`
  from the Phoenix session (set by `StartController` or the dev entry), loads the
  `Study.Session` with its randomized writing runs, and walks the participant through
  them one at a time.

  When the current run's haiku is complete the per-run Likert questionnaire (step #5) is
  shown; only after it is submitted does a **Weiter** button advance to the next
  unfinished writing run. Once all four are done it shows the (placeholder) end card.
  The modification run (#6) / full end screen (#7) are out of scope here.
  """
  use OwnershipAshChatWeb, :live_view

  import OwnershipAshChatWeb.StudyComponents

  alias OwnershipAshChat.Study
  alias OwnershipAshChat.Study.PingPong

  @impl true
  def mount(_params, session, socket) do
    case session["session_id"] do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Keine aktive Studien-Session. Bitte den Zugangslink nutzen.")
         |> redirect(to: ~p"/")}

      session_id ->
        study = Study.get_session!(session_id, load: [:runs])

        socket
        |> assign(:study, study)
        |> assign(:total_runs, length(writing_runs(study)))
        |> assign_run(next_unfinished_run(study))
        |> then(&{:ok, &1})
    end
  end

  @impl true
  def handle_event("set_topic", %{"topic" => topic}, socket) do
    run = Study.set_run_topic!(socket.assigns.run, %{topic: topic})
    {:noreply, assign_run(socket, run)}
  end

  def handle_event("add_passage", %{"text" => text}, socket) do
    # Keep the active run pinned after it completes (so the haiku + questionnaire show);
    # advancing to the next run only happens on the explicit "next_run" click.
    run = Study.add_user_passage!(socket.assigns.run, text)
    {:noreply, assign_run(socket, run)}
  end

  def handle_event("submit_likert", %{"likert" => answers}, socket) do
    likert = Map.new(answers, fn {key, value} -> {key, String.to_integer(value)} end)
    run = Study.submit_likert!(socket.assigns.run, %{likert: likert})
    {:noreply, assign_run(socket, run)}
  end

  def handle_event("next_run", _params, socket) do
    study = Study.get_session!(socket.assigns.study.id, load: [:runs])

    socket
    |> assign(:study, study)
    |> assign_run(next_unfinished_run(study))
    |> then(&{:noreply, &1})
  end

  # Assign the active run (nil → end card) and derived view flags.
  defp assign_run(socket, run) do
    socket
    |> assign(:run, run)
    |> assign(:step, step(run))
    |> assign(:lines_done?, run && lines_done?(run))
    |> assign(:can_add_passage?, run && can_add_passage?(run))
  end

  # First unfinished writing run in presented order; nil once all are complete.
  # A run counts as finished only after its haiku is complete *and* its questionnaire
  # is answered, so a reload mid-questionnaire returns to the same run.
  defp next_unfinished_run(study) do
    study
    |> writing_runs()
    |> Enum.find(&run_unfinished?/1)
  end

  defp run_unfinished?(run), do: is_nil(run.completed_at) or not likert_submitted?(run)

  defp writing_runs(study) do
    (study.runs || [])
    |> Enum.filter(&(&1.kind == :writing))
    |> Enum.sort_by(& &1.run_index)
  end

  defp step(nil), do: :all_done

  defp step(run) do
    cond do
      is_nil(run.completed_at) -> :writing
      not likert_submitted?(run) -> :likert
      true -> :run_complete
    end
  end

  defp can_add_passage?(run), do: is_nil(run.completed_at) and not lines_done?(run)

  defp lines_done?(run), do: length(run.transcript || []) >= PingPong.lines()

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-2xl space-y-6">
        <%= if @step == :all_done do %>
          <section class="rounded-xl border border-base-300 p-6 space-y-3 text-center">
            <h1 class="text-2xl font-semibold">Alle Runs abgeschlossen</h1>
            <p class="text-base-content/70">Danke! Deine Sitzungs-ID zum Zurückgeben:</p>
            <p class="font-mono text-sm break-all">{@study.id}</p>
          </section>
        <% else %>
          <header class="space-y-1">
            <h1 class="text-2xl font-semibold">
              Run {@run.run_index} von {@total_runs}
            </h1>
            <p class="text-sm text-base-content/70">
              {topic_source_label(@run.topic_source)} · {ai_mode_label(@run.ai_mode)}
            </p>
          </header>

          <.run_panel run={@run} can_add_passage?={@can_add_passage?} lines_done?={@lines_done?} />

          <.likert_panel :if={@step in [:likert, :run_complete]} run={@run} />

          <div :if={@step == :run_complete} class="flex justify-end">
            <.button phx-click="next_run">Weiter</.button>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp topic_source_label(:assigned), do: "Vorgegebenes Thema"
  defp topic_source_label(:free), do: "Freies Thema"
  defp topic_source_label(other), do: to_string(other)

  defp ai_mode_label(:with_ai), do: "Mit KI"
  defp ai_mode_label(:without_ai), do: "Ohne KI"
  defp ai_mode_label(other), do: to_string(other)
end
