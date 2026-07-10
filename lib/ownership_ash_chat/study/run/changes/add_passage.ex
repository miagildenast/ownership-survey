defmodule OwnershipAshChat.Study.Run.Changes.AddPassage do
  @moduledoc """
  Appends a human passage to a run's `transcript`, drives the ping-pong line flow,
  and auto-completes the run once it holds its full set of lines.

  A writing run is exactly `PingPong.lines()` (3) lines; who writes which line
  depends on the condition (see `Run.Transcript.ai_turn?/2`):

    * `:free && :with_ai`     → `[human, AI, human]` — the AI writes line 2 right
      after the human's first line.
    * `:assigned && :with_ai` → `[AI, human, AI]` — the AI's opening line is added
      by `BeginRun`; after the human's line the AI closes with line 3.
    * `:without_ai`           → three human lines.

  Every pending AI turn around the new human line is filled (defensively also a
  missing `:assigned` opener). Human input is NEVER syllable-validated. When the
  transcript reaches the line limit the run is finalised: `final_haiku` is
  auto-assembled from the lines (never entered by the participant) and `completed_at`
  is stamped. Further passages on a full run are ignored.

  Non-atomic: it reads the current `transcript` and (for `:with_ai`) calls the LLM,
  so the owning action must set `require_atomic? false`.
  """
  use Ash.Resource.Change

  alias OwnershipAshChat.Study.PingPong
  alias OwnershipAshChat.Study.Run.Transcript

  @impl true
  def change(changeset, _opts, _context) do
    run = changeset.data
    transcript = run.transcript || []

    if length(transcript) >= PingPong.lines() do
      # Run already has its full set of lines; ignore further passages.
      changeset
    else
      text = Ash.Changeset.get_argument(changeset, :text)

      new_transcript =
        transcript
        |> Transcript.fill_ai_turns(run)
        |> Kernel.++([Transcript.passage("user", text)])
        |> Transcript.fill_ai_turns(run)

      changeset
      |> Ash.Changeset.change_attribute(:transcript, new_transcript)
      |> maybe_finalize(new_transcript)
    end
  end

  # Auto-complete once the run holds all its lines: assemble the final haiku from the
  # transcript (in order) and stamp completion.
  defp maybe_finalize(changeset, transcript) do
    if length(transcript) >= PingPong.lines() do
      changeset
      |> Ash.Changeset.change_attribute(:final_haiku, Transcript.assemble(transcript))
      |> Ash.Changeset.change_attribute(:completed_at, DateTime.utc_now())
    else
      changeset
    end
  end
end
