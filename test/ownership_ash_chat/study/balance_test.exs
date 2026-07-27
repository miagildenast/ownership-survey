defmodule OwnershipAshChat.Study.BalanceTest do
  @moduledoc """
  Covers the database side of the balanced randomization: the counters
  `OwnershipAshChat.Study.Randomization` draws against.
  """
  use OwnershipAshChat.DataCase, async: false

  import OwnershipAshChat.StudyGenerators

  alias OwnershipAshChat.Study
  alias OwnershipAshChat.Study.Balance

  # A session whose runs spell out one sequence: run 1 carries the first block's
  # topic_source and leading ai_mode, run 3 the second block's leading ai_mode.
  defp session_with_sequence({first_topic_source, block_1, block_2}, opts \\ []) do
    other_topic_source = if first_topic_source == :assigned, do: :free, else: :assigned

    session =
      generate(
        session(Keyword.put(opts, :topic_source_order, [first_topic_source, other_topic_source]))
      )

    for {run_index, topic_source, ai_mode} <- [
          {1, first_topic_source, block_1},
          {2, first_topic_source, other_ai_mode(block_1)},
          {3, other_topic_source, block_2},
          {4, other_topic_source, other_ai_mode(block_2)}
        ] do
      generate(
        run(
          session_id: session.id,
          run_index: run_index,
          topic_source: topic_source,
          ai_mode: ai_mode
        )
      )
    end

    session
  end

  defp other_ai_mode(:with_ai), do: :without_ai
  defp other_ai_mode(:without_ai), do: :with_ai

  defp modification_run(session, variant) do
    generate(run(session_id: session.id, kind: :modification, variant: variant, run_index: nil))
  end

  describe "writing_snapshot/0" do
    test "counts nothing on an empty database" do
      snapshot = Balance.writing_snapshot()

      assert snapshot.sessions == 0
      assert snapshot.sequence_counts == %{}

      assert snapshot.marginals == %{
               topic: %{assigned: 0, free: 0},
               block_1: %{with_ai: 0, without_ai: 0},
               block_2: %{with_ai: 0, without_ai: 0}
             }
    end

    test "counts each session's sequence and derives the marginal splits" do
      session_with_sequence({:free, :with_ai, :without_ai})
      session_with_sequence({:free, :with_ai, :without_ai})
      session_with_sequence({:assigned, :without_ai, :without_ai})

      snapshot = Balance.writing_snapshot()

      assert snapshot.sessions == 3

      assert snapshot.sequence_counts == %{
               {:free, :with_ai, :without_ai} => 2,
               {:assigned, :without_ai, :without_ai} => 1
             }

      assert snapshot.marginals == %{
               topic: %{assigned: 1, free: 2},
               block_1: %{with_ai: 2, without_ai: 1},
               block_2: %{with_ai: 0, without_ai: 3}
             }
    end

    test "ignores aborted sessions" do
      session_with_sequence({:free, :with_ai, :with_ai})
      session_with_sequence({:assigned, :without_ai, :without_ai}, status: :aborted)

      snapshot = Balance.writing_snapshot()

      assert snapshot.sessions == 1
      assert snapshot.sequence_counts == %{{:free, :with_ai, :with_ai} => 1}
      assert snapshot.marginals.topic == %{assigned: 0, free: 1}
    end

    test "skips sessions that are missing run 1 or run 3" do
      session = generate(session())
      generate(run(session_id: session.id, run_index: 1, topic_source: :free, ai_mode: :with_ai))

      snapshot = Balance.writing_snapshot()

      assert snapshot.sessions == 0
      assert snapshot.sequence_counts == %{}
    end
  end

  describe "variant_counts/0" do
    test "is zero for both variants on an empty database" do
      assert Balance.variant_counts() == %{a: 0, b: 0}
    end

    test "counts the assigned modification variants, ignoring aborted sessions" do
      modification_run(generate(session()), :a)
      modification_run(generate(session()), :b)
      modification_run(generate(session()), :b)
      modification_run(generate(session(status: :aborted)), :b)

      assert Balance.variant_counts() == %{a: 1, b: 2}
    end

    test "ignores writing runs, which carry no variant" do
      generate(run(kind: :writing, run_index: 1))

      assert Balance.variant_counts() == %{a: 0, b: 0}
    end
  end

  describe "variant_split/1" do
    test "returns the session's own variant and the split before it" do
      modification_run(generate(session()), :b)
      modification_run(generate(session()), :b)
      own_session = generate(session())
      modification_run(own_session, :a)

      assert {:a, %{a: 0, b: 2}} = Balance.variant_split(own_session.id)
    end

    test "returns nil for a session without a modification run" do
      modification_run(generate(session()), :a)
      session = generate(session())

      assert {nil, %{a: 1, b: 0}} = Balance.variant_split(session.id)
    end
  end

  describe "wiring into the domain" do
    test "the marks read actions only surface the balancing rows" do
      session = session_with_sequence({:free, :without_ai, :with_ai})
      modification_run(session, :a)

      run_indexes = Study.list_randomization_marks!() |> Enum.map(& &1.run_index) |> Enum.sort()
      assert run_indexes == [1, 3]

      assert [%{variant: :a}] = Study.list_variant_marks!()
    end
  end
end
