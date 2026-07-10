defmodule OwnershipAshChat.Study.Run.Changes.CreateModification do
  @moduledoc """
  Builds the fifth run (`kind: :modification`) from the four completed writing runs.

  Owns everything the LiveView used to do inline:

    * picks the "best" writing run — highest average Likert score, random tie-break
      (`Randomization.best_run/1`);
    * picks a modification variant at random from `Types.Variant` (`:a` = one word,
      `:b` = one line);
    * picks the target line — the participant's own first line. Only user-written
      lines may be modified (`Transcript.first_user_index/1`): `:free && :with_ai`
      → line 1, `:assigned && :with_ai` → line 2, `:without_ai` → line 1;
    * calls the LLM for the new version of that single line and splices it into the
      original haiku, so every other line stays byte-identical;
    * records `variant`, `source_run_index`, `original_haiku`, `modified_haiku`,
      `modified_line_index`, and a 3-passage `transcript` — the unchanged lines keep
      their original roles (`user`/`ai`), the rewritten line gets role `ai_enhanced`.

  Runs in a `before_action` hook: it reads the session's writing runs and calls the
  LLM before the record is inserted.
  """
  use Ash.Resource.Change

  require Ash.Query

  alias OwnershipAshChat.Study.{PingPong, Randomization}
  alias OwnershipAshChat.Study.Run.Transcript
  alias OwnershipAshChat.Study.Types.Variant

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      session_id = Ash.Changeset.get_argument(changeset, :session_id)
      best = Randomization.best_run(writing_runs(session_id))

      variant = Enum.random(Variant.values())
      transcript = best.transcript || []
      line_index = Transcript.first_user_index(transcript) || 0
      original_haiku = best.final_haiku

      new_line = PingPong.respond_modification(original_haiku, variant, line_index)
      modified_haiku = PingPong.replace_line(original_haiku, line_index, new_line)
      modified_transcript = build_transcript(transcript, line_index, new_line)

      # In a before_action hook the changeset is already validated, so set attributes
      # with force_change_attribute/3.
      changeset
      |> Ash.Changeset.force_change_attribute(:kind, :modification)
      |> Ash.Changeset.force_change_attribute(:variant, variant)
      |> Ash.Changeset.force_change_attribute(:source_run_index, best.run_index)
      |> Ash.Changeset.force_change_attribute(:original_haiku, original_haiku)
      |> Ash.Changeset.force_change_attribute(:modified_haiku, modified_haiku)
      |> Ash.Changeset.force_change_attribute(:modified_line_index, line_index)
      |> Ash.Changeset.force_change_attribute(:transcript, modified_transcript)
      |> Ash.Changeset.force_change_attribute(:completed_at, DateTime.utc_now())
    end)
  end

  defp writing_runs(session_id) do
    OwnershipAshChat.Study.Run
    |> Ash.Query.filter(session_id == ^session_id and kind == :writing)
    |> Ash.read!()
  end

  # Copy the source transcript, replacing the target line's passage with an
  # `ai_enhanced` passage carrying the new line. Other passages keep role + text.
  defp build_transcript(transcript, line_index, new_line) do
    transcript
    |> Enum.with_index()
    |> Enum.map(fn {passage, idx} ->
      if idx == line_index do
        Transcript.passage("ai_enhanced", new_line)
      else
        Transcript.passage(role(passage), text(passage))
      end
    end)
  end

  defp role(%{"role" => role}), do: to_string(role)
  defp role(%{role: role}), do: to_string(role)
  defp role(_), do: "user"

  defp text(%{"text" => text}), do: to_string(text)
  defp text(%{text: text}), do: to_string(text)
  defp text(_), do: ""
end
