defmodule OwnershipAshChatWeb.StudyWritingLive do
  @moduledoc """
  Dev-only harness to exercise the study writing flow (plan step #4) against a
  single run, without token entry (#2) or run randomization (#3).

  Mounted at `/dev/study/run/:run_id` behind the `:dev_routes` compile flag. Not the
  participant entry point — it just drives `begin_run` / `add_user_passage` so the flow
  can be walked end to end. The run auto-completes after three lines and assembles its
  own `final_haiku`; there is no manual final-haiku entry.
  """
  use OwnershipAshChatWeb, :live_view

  import OwnershipAshChatWeb.StudyComponents

  alias OwnershipAshChat.Study

  @impl true
  def mount(%{"run_id" => run_id}, _session, socket) do
    {:ok, assign_run(socket, run_id |> Study.get_run!() |> begin_run())}
  end

  # Stamp started_at and (for :assigned/:with_ai) generate the AI's opening line
  # before the run is first shown.
  defp begin_run(%{kind: :writing, started_at: nil} = run), do: Study.begin_run!(run)
  defp begin_run(run), do: run

  @impl true
  def handle_event("add_passage", %{"text" => text}, socket) do
    case String.trim(text) do
      "" ->
        {:noreply, flash_blank_line(socket)}

      text ->
        run = Study.add_user_passage!(socket.assigns.run, text)
        {:noreply, assign_run(socket, run)}
    end
  end

  def handle_event("submit_likert", %{"likert" => answers}, socket) do
    likert = Map.new(answers, fn {key, value} -> {key, String.to_integer(value)} end)
    run = Study.submit_likert!(socket.assigns.run, %{likert: likert})
    {:noreply, assign_run(socket, run)}
  end

  @impl true
  def handle_info(:clear_flash, socket), do: {:noreply, clear_flash(socket)}

  # Blank-line notice that clears itself after a few seconds.
  defp flash_blank_line(socket) do
    Process.send_after(self(), :clear_flash, :timer.seconds(4))
    put_flash(socket, :error, "Bitte gib eine Zeile ein.")
  end

  defp assign_run(socket, run) do
    socket
    |> assign(:run, run)
    |> assign(:can_add_passage?, is_nil(run.completed_at))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-6">
        <header class="space-y-1">
          <h1 class="text-2xl font-semibold">Schreib-Run (Dev)</h1>
          <p class="text-sm text-base-content/70">
            Run {@run.run_index} · {@run.kind} · topic_source: {@run.topic_source} · ai_mode: {@run.ai_mode}
          </p>
        </header>

        <.chat_panel
          :if={is_nil(@run.completed_at)}
          run={@run}
          can_add_passage?={@can_add_passage?}
        />

        <p :if={@run.completed_at} class="text-sm text-success">
          Run abgeschlossen um {@run.completed_at}.
        </p>

        <.likert_screen :if={@run.completed_at && not likert_submitted?(@run)} run={@run} />

        <p :if={@run.completed_at && likert_submitted?(@run)} class="text-sm text-success">
          Fragebogen gespeichert.
        </p>
      </div>
    </Layouts.app>
    """
  end
end
