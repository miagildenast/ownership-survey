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

  alias OwnershipAshChat.Study
  alias OwnershipAshChat.Study.Likert
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
    |> assign(:likert_items, Likert.items())
    |> assign(:likert_options, likert_options())
    |> assign(:likert_submitted?, likert_submitted?(run))
  end

  # The questionnaire is asked once the writing phase has auto-completed.
  defp likert_submitted?(run), do: map_size(run.likert || %{}) > 0

  # `<.input type="select">` options as {label, value} pairs, e.g. {"1 – Stimme gar nicht zu", "1"}.
  defp likert_options do
    Enum.map(Likert.scale(), fn value ->
      {"#{value} – #{Map.fetch!(Likert.scale_labels(), value)}", value}
    end)
  end

  defp likert_value(run, key), do: Map.get(run.likert || %{}, Atom.to_string(key))

  # A run holds exactly `PingPong.lines()` lines (3) regardless of `ai_mode`; once it
  # is full it auto-completes, so no further passages are accepted.
  defp can_add_passage?(run), do: is_nil(run.completed_at) and not lines_done?(run)

  defp lines_done?(run), do: line_count(run.transcript) >= PingPong.lines()

  defp line_count(transcript), do: length(transcript || [])

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
            id={"passage-form-#{@line_count}"}
            phx-submit="add_passage"
            class="space-y-2"
          >
            <.input
              type="textarea"
              name="text"
              value=""
              label="Deine Passage"
              phx-mounted={JS.focus()}
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
            Wird nach der dritten Zeile automatisch zusammengesetzt.
          </p>
          <pre
            :if={@run.final_haiku}
            class="whitespace-pre-wrap text-base-content/80"
          >{@run.final_haiku}</pre>
          <p :if={@run.completed_at} class="text-sm text-success">
            Run abgeschlossen um {@run.completed_at}.
          </p>
        </section>

        <section :if={@run.completed_at} class="rounded-xl border border-base-300 p-4 space-y-3">
          <h2 class="font-medium">Fragebogen</h2>

          <.form
            :if={not @likert_submitted?}
            for={%{}}
            id="likert-form"
            phx-submit="submit_likert"
            class="space-y-4"
          >
            <.input
              :for={item <- @likert_items}
              type="select"
              name={"likert[#{item.key}]"}
              options={@likert_options}
              value={likert_value(@run, item.key)}
              prompt="Bitte wählen"
              label={item.prompt}
              required
            />
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
      </div>
    </Layouts.app>
    """
  end
end
