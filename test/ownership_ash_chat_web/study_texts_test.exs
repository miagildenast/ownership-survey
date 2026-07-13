defmodule OwnershipAshChatWeb.StudyTextsTest do
  use ExUnit.Case, async: true

  alias OwnershipAshChatWeb.StudyTexts

  defp run(attrs) do
    Map.merge(%{topic_source: :free, ai_mode: :without_ai, topic: nil, transcript: []}, attrs)
  end

  describe "task_message/2" do
    test "assigned/with_ai guidance shows at position 0 (before the AI's opening line)" do
      run = run(%{topic_source: :assigned, ai_mode: :with_ai, topic: "Jahreszeiten"})

      msg = StudyTexts.task_message(run, 0)

      assert msg =~ "zweite Zeile"
      assert msg =~ "Jahreszeiten"
      # It is the first thing shown, so nothing repeats it at the participant's line.
      assert StudyTexts.task_message(run, 1) == nil
    end

    test "free/without_ai guidance shows at position 0" do
      run = run(%{topic_source: :free, ai_mode: :without_ai})

      assert StudyTexts.task_message(run, 0) =~ "Haiku"
    end

    test "positions without a configured message yield nil" do
      run = run(%{topic_source: :assigned, ai_mode: :with_ai, topic: "Jahreszeiten"})

      assert StudyTexts.task_message(run, 2) == nil
    end
  end
end
