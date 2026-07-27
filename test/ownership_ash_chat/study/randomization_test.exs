defmodule OwnershipAshChat.Study.RandomizationTest do
  use ExUnit.Case, async: true

  alias OwnershipAshChat.Study.Randomization

  describe "draw_writing_plan/0" do
    test "topic_source_order is a permutation of [:assigned, :free]" do
      {order, _specs, _draw} = Randomization.draw_writing_plan()
      assert Enum.sort(order) == [:assigned, :free]
    end

    test "produces exactly 4 specs with run_index 1..4 in order" do
      {_order, specs, _draw} = Randomization.draw_writing_plan()

      assert length(specs) == 4
      assert Enum.map(specs, & &1.run_index) == [1, 2, 3, 4]
      assert Enum.all?(specs, &(&1.kind == :writing))
    end

    test "nested blocks: runs 1-2 share a topic_source, 3-4 share the other" do
      {order, specs, _draw} = Randomization.draw_writing_plan()
      [r1, r2, r3, r4] = specs

      assert r1.topic_source == r2.topic_source
      assert r3.topic_source == r4.topic_source
      assert r1.topic_source != r3.topic_source
      # The block order matches topic_source_order.
      assert [r1.topic_source, r3.topic_source] == order
    end

    test "assigned specs carry the fixed topic, free specs none" do
      {_order, specs, _draw} = Randomization.draw_writing_plan()

      for spec <- specs do
        case spec.topic_source do
          :assigned -> assert spec.topic == Randomization.assigned_topic()
          :free -> assert is_nil(spec.topic)
        end
      end
    end

    test "each block contains both ai_modes" do
      {_order, specs, _draw} = Randomization.draw_writing_plan()
      [r1, r2, r3, r4] = specs

      assert Enum.sort([r1.ai_mode, r2.ai_mode]) == [:with_ai, :without_ai]
      assert Enum.sort([r3.ai_mode, r4.ai_mode]) == [:with_ai, :without_ai]
    end

    test "all 8 valid sequences are reachable without counters" do
      sequences =
        for _ <- 1..400, into: MapSet.new() do
          {_order, specs, _draw} = Randomization.draw_writing_plan()
          Enum.map(specs, &{&1.topic_source, &1.ai_mode})
        end

      # 2 topic_source orders × 2 ai_mode orders per block = 8.
      assert MapSet.size(sequences) == 8
    end

    test "the draw log reports an all-tied first draw" do
      {_order, _specs, draw} = Randomization.draw_writing_plan()

      assert draw.chosen in Randomization.sequences()
      assert draw.count == 0
      assert draw.tied == 8
      assert draw.others == {0, 0}
      assert draw.total == 0
    end
  end

  describe "draw_writing_plan/1 (balanced)" do
    test "always picks the single least-used sequence" do
      [rare | rest] = Randomization.sequences()
      counts = Map.new(rest, &{&1, 2})

      for _ <- 1..50 do
        {order, specs, draw} = Randomization.draw_writing_plan(counts)

        assert draw.chosen == rare
        assert draw.count == 0
        assert draw.tied == 1
        assert draw.others == {2, 2}
        assert draw.total == 14

        # The specs still expand the chosen sequence, not something else.
        {first_topic_source, block_1, block_2} = rare
        ai_modes = Enum.map(specs, & &1.ai_mode)

        assert hd(order) == first_topic_source
        assert Enum.at(ai_modes, 0) == block_1
        assert Enum.at(ai_modes, 2) == block_2
      end
    end

    test "breaks a tie at random among the least-used sequences" do
      [first, second | rest] = Randomization.sequences()
      counts = Map.new(rest, &{&1, 1})

      chosen =
        for _ <- 1..200, into: MapSet.new() do
          {_order, _specs, draw} = Randomization.draw_writing_plan(counts)
          assert draw.tied == 2
          draw.chosen
        end

      assert chosen == MapSet.new([first, second])
    end

    test "missing keys count as zero draws" do
      {_order, _specs, draw} = Randomization.draw_writing_plan(%{})

      assert draw.total == 0
      assert draw.tied == 8
    end
  end

  describe "expand_sequence/1" do
    test "expands into the four runs in presented order" do
      assert Randomization.expand_sequence({:free, :with_ai, :without_ai}) == [
               {:free, :with_ai},
               {:free, :without_ai},
               {:assigned, :without_ai},
               {:assigned, :with_ai}
             ]
    end
  end

  describe "draw_variant/1" do
    test "picks the variant that is behind" do
      assert {:a, draw} = Randomization.draw_variant(%{a: 3, b: 11})
      assert draw.count == 3
      assert draw.tied == 1
      assert draw.others == {11, 11}
      assert draw.total == 14

      assert {:b, _draw} = Randomization.draw_variant(%{a: 9, b: 8})
    end

    test "breaks a tie at random" do
      chosen =
        for _ <- 1..200, into: MapSet.new() do
          {variant, draw} = Randomization.draw_variant(%{a: 2, b: 2})
          assert draw.tied == 2
          variant
        end

      assert chosen == MapSet.new([:a, :b])
    end

    test "without counters both variants are reachable" do
      chosen =
        for _ <- 1..200, into: MapSet.new() do
          {variant, draw} = Randomization.draw_variant()
          assert draw.total == 0
          variant
        end

      assert chosen == MapSet.new([:a, :b])
    end
  end

  describe "assigned_topic/0" do
    test "defaults to Jahreszeiten and reads the app env override" do
      assert Randomization.assigned_topic() == "Jahreszeiten"

      Application.put_env(:ownership_ash_chat, :study_assigned_topic, "Meer")

      on_exit(fn ->
        Application.put_env(:ownership_ash_chat, :study_assigned_topic, "Jahreszeiten")
      end)

      assert Randomization.assigned_topic() == "Meer"
    end
  end

  describe "best_run/1" do
    # Minimal fake run maps — only fields best_run/1 touches.
    defp fake_run(index, likert) do
      %{run_index: index, final_haiku: "haiku #{index}", likert: likert}
    end

    test "picks the run with the highest Likert average" do
      runs = [
        fake_run(1, %{"a" => 3, "b" => 3}),
        fake_run(2, %{"a" => 5, "b" => 5}),
        fake_run(3, %{"a" => 2, "b" => 2}),
        fake_run(4, %{"a" => 4, "b" => 4})
      ]

      assert Randomization.best_run(runs).run_index == 2
    end

    test "picks one of the tied runs when multiple share the max average" do
      runs = [
        fake_run(1, %{"a" => 5, "b" => 5}),
        fake_run(2, %{"a" => 5, "b" => 5}),
        fake_run(3, %{"a" => 3, "b" => 3})
      ]

      assert Randomization.best_run(runs).run_index in [1, 2]
    end

    test "picks one of the tied runs when all scores are equal" do
      runs = Enum.map(1..4, fn i -> fake_run(i, %{"a" => 4, "b" => 4}) end)

      assert Randomization.best_run(runs).run_index in 1..4
    end

    test "treats empty likert map as average 0.0" do
      runs = [
        fake_run(1, %{}),
        fake_run(2, %{"a" => 1})
      ]

      assert Randomization.best_run(runs).run_index == 2
    end
  end
end
