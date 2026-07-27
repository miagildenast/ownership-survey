defmodule OwnershipAshChat.Study.Session.Changes.SeedRuns do
  @moduledoc """
  Seeds the four `kind: :writing` runs for a freshly started session (AGENTS.md plan
  step #3): draws the nested block randomization, persists `topic_source_order`, and
  creates the runs in an `after_action` hook (same transaction). `:assigned` runs are
  seeded with the fixed study topic (`Randomization.assigned_topic/0`); `:free` runs
  get no topic — the participant's first line sets it implicitly.

  The draw is **balanced**: `Balance.writing_snapshot/0` supplies how often each of the 8
  sequences has been assigned so far, and `Randomization.draw_writing_plan/1` picks the
  least-used one (random only on a tie). The snapshot's marginal splits travel on to
  `Events.session_started/2`, which turns them into the message's reason block.

  Idempotent with the `:start` upsert. On a **fresh insert** the forced attributes
  persist and the session has no runs yet → 4 runs created. On a **resume** (same
  `case_id` hits `upsert_identity :unique_case_id` with `upsert_fields []`) the forced
  attributes are discarded and the runs already exist → seeding skipped. So reloads /
  back-navigation never duplicate runs (open question #8).
  """
  use Ash.Resource.Change

  alias OwnershipAshChat.Notifications.Events
  alias OwnershipAshChat.Study
  alias OwnershipAshChat.Study.{Balance, Randomization}

  @impl true
  def change(changeset, _opts, _context) do
    snapshot = Balance.writing_snapshot()
    {order, specs, draw} = Randomization.draw_writing_plan(snapshot.sequence_counts)

    changeset
    |> Ash.Changeset.force_change_attribute(:topic_source_order, order)
    |> Ash.Changeset.force_change_attribute(:started_at, DateTime.utc_now())
    |> Ash.Changeset.after_action(fn _changeset, session ->
      session = Ash.load!(session, :runs)

      if session.runs in [nil, []] do
        Enum.each(specs, fn spec ->
          Study.create_run!(Map.put(spec, :session_id, session.id))
        end)

        # Fresh insert only (resume skips this branch) → announce a new participant,
        # together with the drawn sequence and why it was drawn.
        Events.session_started(session, Map.put(draw, :marginals, snapshot.marginals))

        {:ok, Ash.load!(session, :runs)}
      else
        {:ok, session}
      end
    end)
  end
end
