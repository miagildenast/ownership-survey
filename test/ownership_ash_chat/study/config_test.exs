defmodule OwnershipAshChat.Study.ConfigTest do
  use ExUnit.Case, async: true

  alias OwnershipAshChat.Study.Config

  # The application boots the real priv/study/config.yml, so the accessors below
  # read that already-loaded configuration.

  describe "accessors (real config)" do
    test "exposes the title and intro" do
      assert is_binary(Config.title())
      assert is_binary(Config.intro_heading())
      assert is_binary(Config.intro_text())
    end

    test "syllable targets are the 5-7-5 map keyed by position" do
      assert Config.syllable_targets() == %{0 => 5, 1 => 7, 2 => 5}
      assert Config.syllable_target(1) == 7
    end

    test "task messages resolve by condition and interpolate downstream" do
      # position 0 for free/without_ai, position 1 for assigned/with_ai (AI opens).
      assert Config.task_message(:free, :without_ai, 0) =~ "Haiku"
      assert Config.task_message(:assigned, :with_ai, 1) =~ "{topic}"
      # An unconfigured combination yields nil.
      assert Config.task_message(:free, :without_ai, 2) == nil
    end

    test "questionnaire items, scale and open questions are present" do
      assert [%{key: k, prompt: p} | _] = Config.likert_items()
      assert is_binary(k) and is_binary(p)
      assert Config.likert_scale() == 1..5
      assert Config.likert_scale_labels()[1] |> is_binary()
      assert length(Config.open_questions()) >= 1
    end

    test "llm prompts and modification templates are present" do
      assert Config.system_preamble() =~ "experiment"
      assert Config.line_prompt(0) =~ "{topic}"
      assert Config.retry_suffix() =~ "{rejected_line}"
      assert Config.modification_prompt_base() =~ "{haiku}"
      assert Config.modification_change(:a) =~ "one word"
      assert Config.modification_change(:b) =~ "Replace"
    end

    test "screens expose heading and body" do
      assert %{heading: h, body: b} = Config.screen(:all_done)
      assert is_binary(h) and is_binary(b)
    end
  end

  describe "load!/1" do
    test "raises with a field-naming message on invalid config" do
      error =
        assert_raise Ash.Error.Invalid, fn ->
          Config.load!("test/support/study/bad_config.yml")
        end

      assert Exception.message(error) =~ "title"
    end

    test "reload/0 round-trips the real config without changing accessors" do
      title = Config.title()
      assert Config.reload()
      assert Config.title() == title
    end
  end
end
