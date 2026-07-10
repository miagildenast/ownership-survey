defmodule OwnershipAshChat.Study.Run.Changes.BeginRun do
  @moduledoc """
  Marks a writing run as started when it first becomes active: stamps `started_at`
  (if not already set) and, when the run opens with an AI turn (`:assigned &&
  :with_ai`), generates the AI's first haiku line so the participant sees it before
  writing (see `Run.Transcript.ai_turn?/2`).

  Idempotent: re-invoking on a started run with a non-empty transcript changes
  nothing.

  Non-atomic: it reads the current record and may call the LLM, so the owning
  action must set `require_atomic? false`.
  """
  use Ash.Resource.Change

  alias OwnershipAshChat.Study.Run.Transcript

  @impl true
  def change(changeset, _opts, _context) do
    run = changeset.data

    changeset
    |> maybe_stamp_started(run)
    |> maybe_open_ai_turn(run)
  end

  defp maybe_stamp_started(changeset, %{started_at: nil}),
    do: Ash.Changeset.change_attribute(changeset, :started_at, DateTime.utc_now())

  defp maybe_stamp_started(changeset, _run), do: changeset

  defp maybe_open_ai_turn(changeset, %{transcript: transcript} = run)
       when transcript in [nil, []] do
    case Transcript.fill_ai_turns([], run) do
      [] -> changeset
      opened -> Ash.Changeset.change_attribute(changeset, :transcript, opened)
    end
  end

  defp maybe_open_ai_turn(changeset, _run), do: changeset
end
