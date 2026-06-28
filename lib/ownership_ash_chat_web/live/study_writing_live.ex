defmodule OwnershipAshChatWeb.StudyWritingLive do
  @moduledoc """
  Dev-only harness to exercise the study writing flow (plan step #4) against a
  single run, without token entry (#2) or run randomization (#3).

  Mounted at `/dev/study/run/:run_id` behind the `:dev_routes` compile flag. Not the
  participant entry point — it just drives `set_topic` / `add_user_passage` so the flow
  can be walked end to end. The run auto-completes after three lines and assembles its
  own `final_haiku`; there is no manual final-haiku entry.
  """
  use OwnershipAshChatWeb, :live_view

  import OwnershipAshChatWeb.StudyComponents

  alias OwnershipAshChat.Study
  alias OwnershipAshChat.Study.PingPong

  @impl true
  def mount(%{"run_id" => run_id}, _session, socket) do
    {:ok, assign_run(socket, Study.get_run!(run_id))}
  end

  @impl true
  def handle_event("set_topic", %{"topic" => topic}, socket) do
    run = Study.set_run_topic!(socket.assigns.run, %{topic: topic})
    {:noreply, assign_run(socket, run)}
  end

  def handle_event("add_passage", %{"text" => text}, socket) do
    run = Study.add_user_passage!(socket.assigns.run, text)
    {:noreply, assign_run(socket, run)}
  end

  def handle_event("submit_likert", %{"likert" => answers}, socket) do
    likert = Map.new(answers, fn {key, value} -> {key, String.to_integer(value)} end)
    run = Study.submit_likert!(socket.assigns.run, %{likert: likert})
    {:noreply, assign_run(socket, run)}
  end

  defp assign_run(socket, run) do
    socket
    |> assign(:run, run)
    |> assign(:line_count, line_count(run.transcript))
    |> assign(:lines_done?, lines_done?(run))
    |> assign(:can_add_passage?, can_add_passage?(run))
  end

  # A run holds exactly `PingPong.lines()` lines (3) regardless of `ai_mode`; once it
  # is full it auto-completes, so no further passages are accepted.
  defp can_add_passage?(run), do: is_nil(run.completed_at) and not lines_done?(run)

  defp lines_done?(run), do: line_count(run.transcript) >= PingPong.lines()

  defp line_count(transcript), do: length(transcript || [])

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-2xl space-y-6">
        <header class="space-y-1">
          <h1 class="text-2xl font-semibold">Schreib-Run (Dev)</h1>
          <p class="text-sm text-base-content/70">
            Run {@run.run_index} · {@run.kind} · topic_source: {@run.topic_source} · ai_mode: {@run.ai_mode}
          </p>
        </header>

        <.run_panel run={@run} can_add_passage?={@can_add_passage?} lines_done?={@lines_done?} />

        <p :if={@run.completed_at} class="text-sm text-success">
          Run abgeschlossen um {@run.completed_at}.
        </p>

        <.likert_panel :if={@run.completed_at} run={@run} />
      </div>
    </Layouts.app>
    """
  end
end
