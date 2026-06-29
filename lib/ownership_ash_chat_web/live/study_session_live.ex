defmodule OwnershipAshChatWeb.StudySessionLive do
  @moduledoc """
  Session-driven study flow. Reads the `session_id` from the Phoenix session (set
  by `StartController` or the dev entry), loads the `Study.Session` with its runs,
  and walks the participant through all five phases:

    1. Four writing runs (plan steps 3–5): writing → Likert → Weiter
    2. Transition card once all four writing runs are complete
    3. Modification run (plan step 6): shows best haiku + AI modification → Likert
    4. End screen (plan step 7): session UUID + session marked :completed
  """
  use OwnershipAshChatWeb, :live_view

  import OwnershipAshChatWeb.StudyComponents

  alias OwnershipAshChat.Study
  alias OwnershipAshChat.Study.PingPong
  alias OwnershipAshChat.Study.Randomization

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
        |> assign_run(find_current_run(study))
        |> then(&{:ok, &1})
    end
  end

  @impl true
  def handle_event("set_topic", %{"topic" => topic}, socket) do
    run = Study.set_run_topic!(socket.assigns.run, %{topic: topic})
    {:noreply, assign_run(socket, run)}
  end

  def handle_event("add_passage", %{"text" => text}, socket) do
    # Keep the active run pinned after it completes (so the haiku + questionnaire
    # show); advancing to the next run only happens on the explicit "next_run" click.
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
    |> advance_run(study)
    |> then(&{:noreply, &1})
  end

  # ---------------------------------------------------------------------------
  # Phase routing
  # ---------------------------------------------------------------------------

  # Determine what to show next and update the socket accordingly.
  defp advance_run(socket, study) do
    case Enum.find(writing_runs(study), &run_unfinished?/1) do
      run when not is_nil(run) ->
        assign_run(socket, run)

      nil ->
        case modification_run(study) do
          nil ->
            # All writing done → create the modification run (blocking LLM call).
            {socket, mod_run} = create_modification_run(socket, study)
            fresh_study = Study.get_session!(study.id, load: [:runs])
            socket |> assign(:study, fresh_study) |> assign_run(mod_run)

          mod_run ->
            if likert_submitted?(mod_run) do
              # Modification run done → mark session complete → end screen.
              Study.complete_session!(study)
              fresh = Study.get_session!(study.id, load: [:runs])
              socket |> assign(:study, fresh) |> assign_run(nil)
            else
              # Mod run exists but questionnaire not yet submitted (resume case).
              assign_run(socket, mod_run)
            end
        end
    end
  end

  defp create_modification_run(socket, study) do
    writing = writing_runs(study)
    {best, tied?} = Randomization.best_run(writing)
    variant = Enum.random([:a, :b, :c])
    modified_haiku = PingPong.respond_modification(best.final_haiku, variant)

    mod_run =
      Study.create_run!(%{
        kind: :modification,
        session_id: study.id,
        variant: variant,
        source_run_index: best.run_index,
        original_haiku: best.final_haiku,
        modified_haiku: modified_haiku,
        completed_at: DateTime.utc_now()
      })

    socket = if tied?, do: put_flash(socket, :info, "picked randomly"), else: socket
    {socket, mod_run}
  end

  # ---------------------------------------------------------------------------
  # Run/step helpers
  # ---------------------------------------------------------------------------

  defp assign_run(socket, run) do
    study = socket.assigns.study

    socket
    |> assign(:run, run)
    |> assign(:step, step(run, study))
    |> assign(:lines_done?, run && run.kind == :writing && lines_done?(run))
    |> assign(:can_add_passage?, run && run.kind == :writing && can_add_passage?(run))
  end

  # Find the run the participant should be on right now.
  # Writing runs first; if all done, the modification run (if it exists and its
  # questionnaire is not yet submitted); nil otherwise.
  defp find_current_run(study) do
    writing_runs(study)
    |> Enum.find(&run_unfinished?/1)
    |> then(fn
      run when not is_nil(run) ->
        run

      nil ->
        mod = modification_run(study)
        if mod && not likert_submitted?(mod), do: mod, else: nil
    end)
  end

  # :pre_modification — all writing done but the modification run has not been
  #   created yet (handles resume between writing runs and the Weiter click).
  # :all_done — modification run is done (or no run exists for some other reason).
  defp step(nil, study) do
    if all_writing_done?(study) and is_nil(modification_run(study)),
      do: :pre_modification,
      else: :all_done
  end

  defp step(run, _study) do
    cond do
      is_nil(run.completed_at) -> :writing
      not likert_submitted?(run) -> :likert
      true -> :run_complete
    end
  end

  defp run_unfinished?(run), do: is_nil(run.completed_at) or not likert_submitted?(run)

  defp all_writing_done?(study),
    do: Enum.all?(writing_runs(study), &(!run_unfinished?(&1)))

  defp modification_run(study),
    do: Enum.find(study.runs || [], &(&1.kind == :modification))

  defp writing_runs(study) do
    (study.runs || [])
    |> Enum.filter(&(&1.kind == :writing))
    |> Enum.sort_by(& &1.run_index)
  end

  defp can_add_passage?(run), do: is_nil(run.completed_at) and not lines_done?(run)
  defp lines_done?(run), do: length(run.transcript || []) >= PingPong.lines()

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-2xl space-y-6">
        <%= if @step == :all_done do %>
          <section class="rounded-xl border border-base-300 p-6 space-y-4 text-center">
            <h1 class="text-2xl font-semibold">Studie abgeschlossen</h1>
            <p class="text-base-content/70">
              Vielen Dank! Bitte notiere deine Sitzungs-ID und gib sie im Fragebogen-Tool ein:
            </p>
            <p class="font-mono text-base break-all select-all bg-base-200 rounded-lg px-4 py-3">
              {@study.id}
            </p>
          </section>
        <% end %>

        <%= if @step == :pre_modification do %>
          <section class="rounded-xl border border-base-300 p-6 space-y-4">
            <h1 class="text-2xl font-semibold">Schreibphase abgeschlossen</h1>
            <p class="text-base-content/70">
              Alle vier Runs wurden abgeschlossen. Im nächsten Schritt siehst du eine
              KI-Modifikation deines besten Haikus und bewertest sie kurz.
            </p>
            <div class="flex justify-end">
              <.button phx-click="next_run">Weiter</.button>
            </div>
          </section>
        <% end %>

        <%= if @step not in [:all_done, :pre_modification] do %>
          <header class="space-y-1">
            <%= if @run.kind == :modification do %>
              <h1 class="text-2xl font-semibold">Modifikations-Run</h1>
              <p class="text-sm text-base-content/70">
                Basierend auf Run {@run.source_run_index}
              </p>
            <% else %>
              <h1 class="text-2xl font-semibold">
                Run {@run.run_index} von {@total_runs}
              </h1>
              <p class="text-sm text-base-content/70">
                {topic_source_label(@run.topic_source)} · {ai_mode_label(@run.ai_mode)} · {@study.case_id}
              </p>
            <% end %>
          </header>

          <%= if @run.kind == :modification do %>
            <.modification_panel run={@run} />
          <% else %>
            <.run_panel
              run={@run}
              can_add_passage?={@can_add_passage?}
              lines_done?={@lines_done?}
            />
          <% end %>

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
