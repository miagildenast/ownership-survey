defmodule OwnershipAshChatWeb.StudySessionLive do
  @moduledoc """
  Session-driven study flow. Reads the `session_id` from the Phoenix session (set
  by `StartController` or the dev entry), loads the `Study.Session` with its runs,
  and walks the participant through all five phases:

    1. Intro with instructions + Start button (only before the first run begins)
    2. Four writing runs in a chat window, each followed by a full-screen Likert
    3. Transition card once all four writing runs are complete
    4. Modification run: full-screen Likert on the modified haiku
    5. End screen: session UUID + session marked :completed
  """
  use OwnershipAshChatWeb, :live_view

  import OwnershipAshChatWeb.StudyComponents

  alias OwnershipAshChat.Study

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
        |> assign(:pending_line, nil)
        |> mount_step(study)
        |> then(&{:ok, &1})
    end
  end

  # Show the intro as long as no writing run has been started; otherwise resume
  # wherever the participant left off (mid-run, open Likert, transition, end).
  defp mount_step(socket, study) do
    first_run = List.first(writing_runs(study))

    if first_run && intro_pending?(study) do
      socket
      |> assign_run(first_run)
      |> assign(:step, :intro)
    else
      assign_run(socket, study |> find_current_run() |> begin_run())
    end
  end

  # No writing run carries any progress yet — reload-safe: as soon as begin_run
  # stamps started_at (or a run holds lines / completed), the intro never returns.
  defp intro_pending?(study) do
    Enum.all?(writing_runs(study), fn run ->
      is_nil(run.started_at) and is_nil(run.completed_at) and (run.transcript || []) == []
    end)
  end

  @impl true
  def handle_event("start_study", _params, socket) do
    # Begins the first run; for :assigned/:with_ai this generates the AI's opening
    # line (blocking LLM call — the Start button shows a phx-disable-with state).
    {:noreply, assign_run(socket, begin_run(socket.assigns.run))}
  end

  def handle_event("add_passage", %{"text" => text}, socket) do
    # The user's line is shown immediately (:pending_line); persisting it — and,
    # for AI turns, the LLM reply — runs async so the chat stays responsive.
    # Once the third line lands the run auto-completes and the step derives
    # :likert, swapping the chat for the full-screen questionnaire.
    # Blank input never reaches the domain (the browser's `required` only blocks
    # the empty string, not whitespace-only lines).
    case String.trim(text) do
      "" ->
        {:noreply, flash_blank_line(socket)}

      text ->
        run = socket.assigns.run

        socket
        |> assign(:pending_line, text)
        |> start_async(:add_passage, fn -> Study.add_user_passage!(run, text) end)
        |> then(&{:noreply, &1})
    end
  end

  def handle_event("submit_likert", %{"likert" => answers}, socket) do
    likert = Map.new(answers, fn {key, value} -> {key, String.to_integer(value)} end)
    Study.submit_likert!(socket.assigns.run, %{likert: likert})

    study = Study.get_session!(socket.assigns.study.id, load: [:runs])

    socket
    |> assign(:study, study)
    |> after_likert(study)
    |> then(&{:noreply, &1})
  end

  def handle_event("start_modification", _params, socket) do
    # All writing done → create the modification run (blocking LLM call). The
    # domain picks the best run, variant, and target line (see
    # Run.Changes.CreateModification). The run is created already completed, so
    # the step lands directly on :likert showing the modified haiku.
    mod_run = Study.create_modification_run!(socket.assigns.study.id)
    study = Study.get_session!(socket.assigns.study.id, load: [:runs])

    socket
    |> assign(:study, study)
    |> assign_run(mod_run)
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_info(:clear_flash, socket), do: {:noreply, clear_flash(socket)}

  @impl true
  def handle_async(:add_passage, {:ok, run}, socket) do
    {:noreply, socket |> assign(:pending_line, nil) |> assign_run(run)}
  end

  def handle_async(:add_passage, {:exit, _reason}, socket) do
    socket
    |> assign(:pending_line, nil)
    |> put_flash(:error, "Speichern fehlgeschlagen. Bitte versuche es erneut.")
    |> then(&{:noreply, &1})
  end

  # ---------------------------------------------------------------------------
  # Phase routing
  # ---------------------------------------------------------------------------

  # After a questionnaire is submitted, move straight to whatever comes next:
  # the next writing run's chat, the pre-modification card, or the end screen.
  defp after_likert(socket, study) do
    case Enum.find(writing_runs(study), &run_unfinished?/1) do
      run when not is_nil(run) ->
        assign_run(socket, begin_run(run))

      nil ->
        case modification_run(study) do
          nil ->
            # :pre_modification — the participant triggers the (blocking) run
            # creation explicitly via the transition card's button.
            assign_run(socket, nil)

          _mod_run ->
            # The modification run's Likert was just submitted → session done.
            Study.complete_session!(study)
            fresh = Study.get_session!(study.id, load: [:runs])
            socket |> assign(:study, fresh) |> assign_run(nil)
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Run/step helpers
  # ---------------------------------------------------------------------------

  # Blank-line notice that clears itself after a few seconds.
  defp flash_blank_line(socket) do
    Process.send_after(self(), :clear_flash, :timer.seconds(4))
    put_flash(socket, :error, "Bitte gib eine Zeile ein.")
  end

  # Mark a freshly presented writing run as started; for :assigned/:with_ai runs this
  # also generates the AI's opening line (blocking LLM call, same pattern as the
  # modification run — the triggering button shows a phx-disable-with wait state).
  defp begin_run(%{kind: :writing, started_at: nil} = run), do: Study.begin_run!(run)
  defp begin_run(run), do: run

  defp assign_run(socket, run) do
    socket
    |> assign(:run, run)
    |> assign(:step, step(run, socket.assigns.study))
    |> assign(:can_add_passage?, run && run.kind == :writing && is_nil(run.completed_at))
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
  #   created yet (handles resume between writing runs and the button click).
  # :all_done — modification run is done (or no run exists for some other reason).
  defp step(nil, study) do
    if all_writing_done?(study) and is_nil(modification_run(study)),
      do: :pre_modification,
      else: :all_done
  end

  defp step(run, _study) do
    if is_nil(run.completed_at), do: :writing, else: :likert
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

  # Wide column for the intro's split layout and the chat; narrow otherwise.
  defp step_width(step) when step in [:intro, :writing], do: "max-w-5xl"
  defp step_width(_step), do: "max-w-2xl"

  # Instructions/chat split: stacked on mobile (instructions capped, chat takes
  # the remaining viewport height), two columns from md up.
  defp split_grid do
    "grid min-h-0 flex-1 grid-rows-[auto_minmax(0,1fr)] gap-4 md:grid-cols-2 md:grid-rows-1 md:gap-6"
  end

  # Overall study progress in percent: the four writing runs plus the
  # modification run count as equal units; a run's unit is done once its
  # questionnaire is reached/submitted.
  defp progress_percent(step, run, total_runs) do
    units = total_runs + 1

    done =
      case {step, run} do
        {:writing, run} -> run.run_index - 1
        {:likert, %{kind: :writing} = run} -> run.run_index
        {:likert, %{kind: :modification}} -> total_runs + 0.5
        {:pre_modification, _run} -> total_runs
        {_step, _run} -> 0
      end

    round(done / units * 100)
  end

  defp progress_label(:writing, run, total_runs), do: "Run #{run.run_index} von #{total_runs}"

  defp progress_label(:likert, %{kind: :writing} = run, total_runs),
    do: "Run #{run.run_index} von #{total_runs}"

  defp progress_label(_step, _run, _total_runs), do: "Abschluss"

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      max_width={step_width(@step)}
      fullscreen={@step in [:intro, :writing]}
    >
      <div class={[
        "space-y-6",
        @step in [:intro, :writing] && "flex h-full min-h-0 flex-col"
      ]}>
        <.progress_bar
          :if={@step in [:writing, :likert, :pre_modification]}
          percent={progress_percent(@step, @run, @total_runs)}
          label={progress_label(@step, @run, @total_runs)}
        />

        <%= if @step == :intro do %>
          <div class={split_grid()}>
            <.instructions_panel show_start />
            <.chat_panel run={@run} can_add_passage?={false} disabled />
          </div>
        <% end %>

        <%= if @step == :writing do %>
          <div class={split_grid()}>
            <.instructions_panel />
            <.chat_panel
              run={@run}
              can_add_passage?={@can_add_passage?}
              pending_line={@pending_line}
            />
          </div>
        <% end %>

        <%= if @step == :likert do %>
          <.likert_screen run={@run} />
        <% end %>

        <%= if @step == :pre_modification do %>
          <section class="rounded-xl border border-base-300 p-6 space-y-4">
            <h1 class="text-2xl font-semibold">Schreibphase abgeschlossen</h1>
            <p class="text-base-content/70">
              Alle vier Runs wurden abgeschlossen. Im nächsten Schritt siehst du eine
              KI-Modifikation deines besten Haikus und bewertest sie kurz.
            </p>
            <div class="flex justify-end" phx-mounted={JS.focus(to: "#weiter-btn")}>
              <.button
                id="weiter-btn"
                phx-click="start_modification"
                phx-disable-with="Bitte warten, KI modifiziert…"
              >
                Weiter – KI-Modifikation starten
              </.button>
            </div>
          </section>
        <% end %>

        <%= if @step == :all_done do %>
          <section class="rounded-xl border border-base-300 p-6 space-y-4 text-center">
            <h1 class="text-2xl font-semibold">Studie abgeschlossen</h1>
            <p class="text-base-content/70">
              Vielen Dank! Bitte kopiere deine Sitzungs-ID und gib sie im Fragebogen-Tool ein:
            </p>
            <p class="font-mono text-base break-all select-all bg-base-200 rounded-lg px-4 py-3">
              {@study.id}
            </p>
            <button
              type="button"
              phx-hook=".CopyId"
              id="copy-session-id"
              data-copy={@study.id}
              data-label="📋 Kopieren"
              data-label-copied="✅ Kopiert!"
              class="inline-flex items-center gap-2 rounded-lg bg-primary px-4 py-2 text-primary-content hover:opacity-90 transition-opacity"
            >
              📋 Kopieren
            </button>
            <script :type={Phoenix.LiveView.ColocatedHook} name=".CopyId">
              export default {
                mounted() {
                  this.timeout = null;
                  this.el.addEventListener("click", () => {
                    navigator.clipboard.writeText(this.el.dataset.copy);
                    this.el.textContent = this.el.dataset.labelCopied;
                    this.el.classList.add("bg-success", "text-success-content");
                    this.el.classList.remove("bg-primary", "text-primary-content");

                    clearTimeout(this.timeout);
                    this.timeout = setTimeout(() => {
                      this.el.textContent = this.el.dataset.label;
                      this.el.classList.remove("bg-success", "text-success-content");
                      this.el.classList.add("bg-primary", "text-primary-content");
                    }, 3000);
                  });
                },
                destroyed() {
                  clearTimeout(this.timeout);
                }
              }
            </script>
          </section>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
