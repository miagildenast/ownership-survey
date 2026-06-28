defmodule OwnershipAshChat.Study.RandomizationTest do
  use ExUnit.Case, async: true

  alias OwnershipAshChat.Study.Randomization

  describe "draw_writing_plan/0" do
    test "topic_source_order is a permutation of [:assigned, :free]" do
      {order, _specs} = Randomization.draw_writing_plan()
      assert Enum.sort(order) == [:assigned, :free]
    end

    test "produces exactly 4 specs with run_index 1..4 in order" do
      {_order, specs} = Randomization.draw_writing_plan()

      assert length(specs) == 4
      assert Enum.map(specs, & &1.run_index) == [1, 2, 3, 4]
      assert Enum.all?(specs, &(&1.kind == :writing))
    end

    test "nested blocks: runs 1-2 share a topic_source, 3-4 share the other" do
      {order, specs} = Randomization.draw_writing_plan()
      [r1, r2, r3, r4] = specs

      assert r1.topic_source == r2.topic_source
      assert r3.topic_source == r4.topic_source
      assert r1.topic_source != r3.topic_source
      # The block order matches topic_source_order.
      assert [r1.topic_source, r3.topic_source] == order
    end

    test "each block contains both ai_modes" do
      {_order, specs} = Randomization.draw_writing_plan()
      [r1, r2, r3, r4] = specs

      assert Enum.sort([r1.ai_mode, r2.ai_mode]) == [:with_ai, :without_ai]
      assert Enum.sort([r3.ai_mode, r4.ai_mode]) == [:with_ai, :without_ai]
    end

    test "all 8 valid sequences are reachable over many draws" do
      sequences =
        for _ <- 1..400, into: MapSet.new() do
          {_order, specs} = Randomization.draw_writing_plan()
          Enum.map(specs, &{&1.topic_source, &1.ai_mode})
        end

      # 2 topic_source orders × 2 ai_mode orders per block = 8.
      assert MapSet.size(sequences) == 8
    end
  end
end
