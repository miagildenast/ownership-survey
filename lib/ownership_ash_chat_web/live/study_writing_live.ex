defmodule OwnershipAshChatWeb.StudyWritingLive do
  @moduledoc """
  Dev-only harness to exercise the study writing flow (plan step #4) against a
  single run, without token entry (#2) or run randomization (#3).

  Mounted at `/dev/study/run/:run_id` behind the `:dev_routes` compile flag. Not the
  participant entry point — it just drives `set_topic` / `add_user_passage` /
  `set_final_haiku` so the flow can be walked end to end.
  """
  use OwnershipAshChatWeb, :live_view

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

  def handle_event("set_final_haiku", %{"final_haiku" => haiku}, socket) do
    run = Study.set_final_haiku!(socket.assigns.run, %{final_haiku: haiku})
    {:noreply, assign_run(socket, run)}
  end

  defp assign_run(socket, run) do
    socket
    |> assign(:run, run)
    |> assign(:rounds_done?, rounds_done?(run))
    |> assign(:can_add_passage?, can_add_passage?(run))
  end

  # `:with_ai` runs stop at the round limit; `:without_ai` runs (plain solo writing)
  # accept passages until the participant submits the final haiku.
  defp can_add_passage?(%{ai_mode: :with_ai} = run), do: not rounds_done?(run)
  defp can_add_passage?(run), do: is_nil(run.completed_at)

  defp rounds_done?(%{ai_mode: :with_ai} = run), do: user_count(run.transcript) >= PingPong.rounds()
  defp rounds_done?(_run), do: true

  defp user_count(transcript) do
    Enum.count(transcript || [], fn p -> passage_role(p) == "user" end)
  end

  defp passage_role(%{"role" => role}), do: role
  defp passage_role(%{role: role}), do: to_string(role)
  defp passage_role(_), do: nil

  defp passage_text(%{"text" => text}), do: text
  defp passage_text(%{text: text}), do: text
  defp passage_text(_), do: ""

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

        <section class="rounded-xl border border-base-300 p-4 space-y-3">
          <h2 class="font-medium">Thema</h2>
          <p :if={@run.topic} class="text-base-content/80">{@run.topic}</p>
          <.form
            :if={@run.topic_source == :free}
            for={%{}}
            id="topic-form"
            phx-submit="set_topic"
            class="flex gap-2 items-end"
          >
            <.input type="text" name="topic" value={@run.topic || ""} label="Thema wählen" />
            <.button>Speichern</.button>
          </.form>
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
            <.input type="textarea" name="text" value="" label="Deine Passage" />
            <.button>Senden</.button>
          </.form>
          <p :if={@run.ai_mode == :with_ai and @rounds_done?} class="text-sm text-base-content/60">
            Ping-Pong abgeschlossen ({PingPong.rounds()} Runden).
          </p>
        </section>

        <section class="rounded-xl border border-base-300 p-4 space-y-3">
          <h2 class="font-medium">Finales Haiku</h2>
          <pre :if={@run.final_haiku} class="whitespace-pre-wrap text-base-content/80">{@run.final_haiku}</pre>
          <.form for={%{}} id="final-haiku-form" phx-submit="set_final_haiku" class="space-y-2">
            <.input type="textarea" name="final_haiku" value={@run.final_haiku || ""} label="Haiku eintragen" />
            <.button>Abschließen</.button>
          </.form>
          <p :if={@run.completed_at} class="text-sm text-success">
            Run abgeschlossen um {@run.completed_at}.
          </p>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
