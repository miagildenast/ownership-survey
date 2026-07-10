defmodule OwnershipAshChat.Study.Run.Transcript do
  @moduledoc """
  Transcript helpers shared by the run changes (`AddPassage`, `BeginRun`):
  the condition-dependent AI-turn schedule, passage building (including the AI
  passage via `PingPong.respond/1`), and haiku assembly.

  The AI-turn schedule by 0-based line position:

    * `:assigned && :with_ai` → AI writes lines 0 and 2 (`[AI, user, AI]`)
    * `:free && :with_ai`     → AI writes line 1 (`[user, AI, user]`)
    * `:without_ai`           → no AI turns
  """

  alias OwnershipAshChat.Study.PingPong

  @doc "Whether the line at the given 0-based position is the AI's turn for this run."
  def ai_turn?(%{ai_mode: :with_ai, topic_source: :assigned}, position),
    do: position in [0, 2]

  def ai_turn?(%{ai_mode: :with_ai}, position), do: position == 1
  def ai_turn?(_run, _position), do: false

  @doc """
  Append AI passages for every consecutive AI turn at the current transcript end,
  stopping at the run's line limit. No-op when the next line is a human turn.
  """
  def fill_ai_turns(transcript, run) do
    position = length(transcript)

    if position < PingPong.lines() and ai_turn?(run, position) do
      transcript
      |> Kernel.++([ai_passage(%{run | transcript: transcript})])
      |> fill_ai_turns(run)
    else
      transcript
    end
  end

  # Build the AI passage from the responder result. The responder may return a plain
  # binary (test stubs) or `{:ok, line}` / `{:fallback, line, candidates}` from the
  # validated ping-pong loop. A fallback line carries its tried candidates on the
  # passage (jsonb) so the UI can flag it and the export retains it.
  defp ai_passage(run) do
    case PingPong.respond(run) do
      {:ok, line} ->
        passage("ai", line)

      {:fallback, line, candidates} ->
        Map.merge(passage("ai", line), %{
          "fallback" => true,
          "candidates" => Enum.map(candidates, &to_string/1)
        })

      line when is_binary(line) ->
        passage("ai", line)
    end
  end

  @doc """
  Build one transcript passage map.

  Roles: `"user"` and `"ai"` for writing runs; the modification run additionally
  uses `"ai_enhanced"` for the single line the AI rewrote (see
  `Run.Changes.CreateModification`).
  """
  def passage(role, text) do
    %{"role" => role, "text" => to_string(text), "at" => DateTime.utc_now()}
  end

  @doc """
  0-based index of the first participant-written passage in a transcript, or `nil`
  if there is none. This is the only line the modification run may change (the
  participant's own first line).
  """
  def first_user_index(transcript) do
    Enum.find_index(transcript || [], fn passage -> role(passage) == "user" end)
  end

  defp role(%{"role" => role}), do: to_string(role)
  defp role(%{role: role}), do: to_string(role)
  defp role(_), do: nil

  @doc "Join the transcript's lines (in order) into the final haiku text."
  def assemble(transcript) do
    Enum.map_join(transcript, "\n", &text/1)
  end

  defp text(%{"text" => text}), do: to_string(text)
  defp text(%{text: text}), do: to_string(text)
  defp text(_), do: ""
end
