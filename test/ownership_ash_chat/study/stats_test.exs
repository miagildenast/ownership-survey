defmodule OwnershipAshChat.Study.StatsTest do
  use OwnershipAshChat.DataCase, async: false

  import OwnershipAshChat.StudyGenerators

  alias OwnershipAshChat.Study
  alias OwnershipAshChat.Study.Stats

  @likert %{"item_1" => 4, "item_2" => 5}

  # One session with its four writing runs, `ai_modes` in presented order (run_index
  # 1..4), plus an optional modification run.
  defp seed_session(opts) do
    {ai_modes, opts} = Keyword.pop!(opts, :ai_modes)
    {answered, opts} = Keyword.pop(opts, :answered, 0)
    {modification_answered, opts} = Keyword.pop(opts, :modification_answered, false)
    {modification_variant, opts} = Keyword.pop(opts, :modification_variant, :a)

    session = generate(session(opts))

    ai_modes
    |> Enum.with_index(1)
    |> Enum.each(fn {ai_mode, run_index} ->
      generate(
        run(
          session_id: session.id,
          run_index: run_index,
          topic_source: Enum.at(session.topic_source_order, div(run_index - 1, 2)),
          ai_mode: ai_mode,
          likert: if(run_index <= answered, do: @likert, else: %{})
        )
      )
    end)

    if modification_answered do
      generate(
        run(
          session_id: session.id,
          run_index: nil,
          kind: :modification,
          variant: modification_variant,
          likert: @likert
        )
      )
    end

    session
  end

  # Statistics over exactly the given sessions, reloaded with their runs.
  defp stats_for(sessions) do
    sessions |> Enum.map(&Study.export_session!(&1.id)) |> Stats.compute()
  end

  defp minutes_ago_pair(duration_minutes) do
    started = DateTime.add(DateTime.utc_now(), -duration_minutes * 60, :second)
    {started, DateTime.utc_now()}
  end

  defp completed_session(duration_minutes, opts) do
    {started_at, completed_at} = minutes_ago_pair(duration_minutes)

    seed_session(
      Keyword.merge(opts,
        status: :completed,
        started_at: started_at,
        completed_at: completed_at
      )
    )
  end

  describe "compute/1" do
    setup do
      # 10 min, free block first, with_ai first in both blocks, all 4 + modification
      # questionnaires submitted.
      a =
        completed_session(10,
          topic_source_order: [:free, :assigned],
          ai_modes: [:with_ai, :without_ai, :with_ai, :without_ai],
          answered: 4,
          modification_answered: true
        )

      # 20 min, assigned block first, without_ai first in both blocks, 2 of 4 submitted,
      # modification run of the other variant (whole line).
      b =
        completed_session(20,
          topic_source_order: [:assigned, :free],
          ai_modes: [:without_ai, :with_ai, :without_ai, :with_ai],
          answered: 2,
          modification_answered: true,
          modification_variant: :b
        )

      # Still running: counts in the session totals but not in the durations.
      c =
        seed_session(
          topic_source_order: [:free, :assigned],
          ai_modes: [:with_ai, :without_ai, :without_ai, :with_ai],
          answered: 1
        )

      # Compute over exactly the sessions seeded here (loaded with their runs), so a
      # stray row in the test DB can't skew the counts.
      %{stats: stats_for([a, b, c])}
    end

    test "counts sessions per status", %{stats: stats} do
      assert stats.sessions == %{total: 3, completed: 2, in_progress: 1, aborted: 0}
    end

    test "counts submitted questionnaires per run kind", %{stats: stats} do
      assert stats.surveys == %{submitted: 9, writing: 7, modification: 2}
    end

    test "counts modification runs per variant", %{stats: stats} do
      assert stats.modifications == %{total: 2, one_word: 1, whole_line: 1}
    end

    test "reports median/min/max duration over sessions with both timestamps", %{stats: stats} do
      assert stats.durations.sessions == 2
      # Only the two completed sessions (10 + 20 min); median of an even count is the
      # average of the two middle values.
      assert_in_delta stats.durations.median_seconds, 900, 2
      assert_in_delta stats.durations.min_seconds, 600, 2
      assert_in_delta stats.durations.max_seconds, 1200, 2
    end

    test "counts which topic_source block came first", %{stats: stats} do
      assert stats.randomization.first_topic_source == %{free: 2, assigned: 1}
    end

    test "counts which ai_mode came first inside each block", %{stats: stats} do
      assert stats.randomization.first_ai_mode == %{
               # run_index 1: with_ai, without_ai, with_ai
               block_1: %{with_ai: 2, without_ai: 1},
               # run_index 3: with_ai, without_ai, without_ai
               block_2: %{with_ai: 1, without_ai: 2}
             }
    end

    test "to_json! emits the same numbers", %{stats: stats} do
      decoded = stats |> Stats.to_json!() |> Jason.decode!()

      assert decoded["sessions"] == %{
               "total" => 3,
               "completed" => 2,
               "in_progress" => 1,
               "aborted" => 0
             }

      assert decoded["surveys"]["submitted"] == 9
      assert decoded["modifications"] == %{"total" => 2, "one_word" => 1, "whole_line" => 1}
      assert decoded["randomization"]["first_ai_mode"]["block_1"]["with_ai"] == 2
      assert is_binary(decoded["generated_at"])
    end
  end

  describe "compute/1 edge cases" do
    test "empty data yields zeroed counts and no durations" do
      stats = Stats.compute([])

      assert stats.sessions == %{total: 0, completed: 0, in_progress: 0, aborted: 0}
      assert stats.surveys == %{submitted: 0, writing: 0, modification: 0}
      assert stats.modifications == %{total: 0, one_word: 0, whole_line: 0}

      assert stats.durations == %{
               sessions: 0,
               median_seconds: nil,
               min_seconds: nil,
               max_seconds: nil
             }

      assert stats.randomization.first_topic_source == %{assigned: 0, free: 0}
    end

    test "an odd number of durations takes the middle value" do
      sessions =
        Enum.map([5, 9, 30], fn minutes ->
          completed_session(minutes,
            topic_source_order: [:free, :assigned],
            ai_modes: [:with_ai, :without_ai, :with_ai, :without_ai]
          )
        end)

      stats = stats_for(sessions)

      assert stats.durations.sessions == 3
      assert_in_delta stats.durations.median_seconds, 9 * 60, 2
    end

    test "raises when runs were not loaded" do
      session = generate(session())

      assert_raise ArgumentError, ~r/no runs loaded/, fn ->
        Stats.compute([Study.get_session!(session.id)])
      end
    end
  end

  describe "collect!/0" do
    test "reads every session from the repo" do
      before = Stats.collect!()

      seed_session(ai_modes: [:with_ai, :without_ai, :with_ai, :without_ai], answered: 4)

      stats = Stats.collect!()

      assert stats.sessions.total == before.sessions.total + 1
      assert stats.surveys.submitted == before.surveys.submitted + 4
    end
  end

  describe "humanize_duration/1" do
    test "renders hours/minutes/seconds and drops leading zero units" do
      assert Stats.humanize_duration(nil) == "n/a"
      assert Stats.humanize_duration(0) == "0s"
      assert Stats.humanize_duration(7) == "7s"
      assert Stats.humanize_duration(900.0) == "15m 0s"
      assert Stats.humanize_duration(1122) == "18m 42s"
      assert Stats.humanize_duration(3849) == "1h 4m 9s"
    end
  end
end
