defmodule OwnershipAshChat.Study.Run.Changes.AddPassage do
  @moduledoc """
  Appends a human passage to a run's `transcript`, drives the ping-pong line flow,
  and auto-completes the run once it holds its full set of lines.

  A writing run is exactly `PingPong.lines()` (3) lines:

    * `:with_ai`    → `[human, AI, human]` — the AI generates line 2 right after the
      human's first line.
    * `:without_ai` → three human lines.

  When the transcript reaches the line limit the run is finalised: `final_haiku` is
  auto-assembled from the lines (never entered by the participant) and `completed_at`
  is stamped. Further passages on a full run are ignored.

  Non-atomic: it reads the current `transcript` and (for `:with_ai`) calls the LLM,
  so the owning action must set `require_atomic? false`.
  """
  use Ash.Resource.Change

  alias OwnershipAshChat.Study.PingPong

  @impl true
  def change(changeset, _opts, _context) do
    run = changeset.data
    transcript = run.transcript || []

    if length(transcript) >= PingPong.lines() do
      # Run already has its full set of lines; ignore further passages.
      changeset
    else
      text = Ash.Changeset.get_argument(changeset, :text)
      with_user = transcript ++ [passage("user", text)]

      # The AI takes exactly one turn: line 2, right after the human's first line.
      new_transcript =
        if run.ai_mode == :with_ai and user_count(transcript) == 0 do
          with_user ++ [ai_passage(%{run | transcript: with_user})]
        else
          with_user
        end

      changeset = Ash.Changeset.change_attribute(changeset, :transcript, new_transcript)
      maybe_finalize(changeset, new_transcript)
    end
  end

  # Auto-complete once the run holds all its lines: assemble the final haiku from the
  # transcript (in order) and stamp completion.
  defp maybe_finalize(changeset, transcript) do
    if length(transcript) >= PingPong.lines() do
      changeset
      |> Ash.Changeset.change_attribute(:final_haiku, assemble(transcript))
      |> Ash.Changeset.change_attribute(:completed_at, DateTime.utc_now())
    else
      changeset
    end
  end

  defp assemble(transcript) do
    transcript |> Enum.map_join("\n", &text/1)
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

  defp passage(role, text) do
    %{"role" => role, "text" => to_string(text), "at" => DateTime.utc_now()}
  end

  defp user_count(transcript) do
    Enum.count(transcript, fn
      %{"role" => "user"} -> true
      %{role: :user} -> true
      _ -> false
    end)
  end

  defp text(%{"text" => text}), do: to_string(text)
  defp text(%{text: text}), do: to_string(text)
  defp text(_), do: ""
end
