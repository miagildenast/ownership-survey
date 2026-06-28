defmodule OwnershipAshChat.Study.Session.Changes.SeedRuns do
  @moduledoc """
  Seeds the four `kind: :writing` runs for a freshly started session (AGENTS.md plan
  step #3): draws the nested block randomization, persists `topic_source_order`, and
  creates the runs in an `after_action` hook (same transaction).

  Idempotent with the `:start` upsert. On a **fresh insert** the forced attributes
  persist and the session has no runs yet → 4 runs created. On a **resume** (same
  `case_id` hits `upsert_identity :unique_case_id` with `upsert_fields []`) the forced
  attributes are discarded and the runs already exist → seeding skipped. So reloads /
  back-navigation never duplicate runs (open question #8).
  """
  use Ash.Resource.Change

  alias OwnershipAshChat.Study
  alias OwnershipAshChat.Study.Randomization

  @impl true
  def change(changeset, _opts, _context) do
    {order, specs} = Randomization.draw_writing_plan()

    changeset
    |> Ash.Changeset.force_change_attribute(:topic_source_order, order)
    |> Ash.Changeset.force_change_attribute(:started_at, DateTime.utc_now())
    |> Ash.Changeset.after_action(fn _changeset, session ->
      session = Ash.load!(session, :runs)

      if session.runs in [nil, []] do
        Enum.each(specs, fn spec ->
          Study.create_run!(Map.put(spec, :session_id, session.id))
        end)

        {:ok, Ash.load!(session, :runs)}
      else
        {:ok, session}
      end
    end)
  end
end
