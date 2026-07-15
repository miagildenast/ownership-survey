defmodule OwnershipAshChat.Study.ConfigTest do
  use ExUnit.Case, async: true

  alias OwnershipAshChat.Study.Config

  # The application boots the test fixture (test/support/study/config.yml, wired via
  # `study_config_path` in config/test.exs), so the accessors below read that
  # already-loaded configuration — never the real priv/study/config.yml.

  describe "accessors (fixture config)" do
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
      # position 0 holds the participant guidance for each condition.
      assert Config.task_message(:free, :without_ai, 0) =~ "Haiku"
      assert Config.task_message(:assigned, :with_ai, 0) =~ "{topic}"
      # An unconfigured combination yields nil.
      assert Config.task_message(:free, :without_ai, 2) == nil
    end

    test "questionnaire items, scale and open questions are present" do
      assert [%{key: k, prompt: p, labels: _} | _] = Config.likert_items()
      assert is_binary(k) and is_binary(p)
      assert Config.likert_scale() == 1..5
      assert Config.likert_scale_labels()[1] |> is_binary()
      assert length(Config.open_questions()) >= 1
    end

    test "questionnaire haiku intro exposes before/after copy" do
      assert %{before: before, after: aft} = Config.haiku_intro()
      assert is_binary(before) and is_binary(aft)
    end

    test "an item can override scale labels over the full scale; others fall back" do
      items = Map.new(Config.likert_items(), &{&1.key, &1.labels})

      # The fixture's overriding item carries a full value => label map…
      override = Enum.find_value(items, fn {_k, labels} -> labels end)
      assert map_size(override) == Enum.count(Config.likert_scale())

      # …while at least one item has no per-item labels (uses the global set).
      assert Enum.any?(items, fn {_k, labels} -> is_nil(labels) end)
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

    test "pre_modification defaults to not skipped" do
      refute Config.skip_pre_modification?()
    end

    test "all_done defaults to copy mode when no mode is configured" do
      assert Config.all_done_mode() == :copy
    end
  end

  describe "screens.all_done redirect mode" do
    @real_config "priv/study/config.yml"

    setup do
      fixture = Config.path()
      on_exit(fn -> Config.load!(fixture) end)
      Config.load!(@real_config)
      :ok
    end

    test "exposes redirect mode and button label" do
      assert Config.all_done_mode() == :redirect
      assert Config.all_done_button_label() == "Zurück zum Fragebogen"
    end

    test "builds the return URL with substituted, URL-encoded params" do
      url = Config.all_done_redirect_url("a b/c", "sess-1")
      assert url == "https://www.sosci.uni-hamburg.de/aiownership/?i=a+b%2Fc"
    end
  end

  describe "screens.all_done redirect validation" do
    setup do
      fixture = Config.path()
      on_exit(fn -> Config.load!(fixture) end)
      :ok
    end

    test "raises when mode is :redirect but no redirect block is given" do
      # The copy-mode fixture has no redirect block; flipping it to :redirect must fail.
      config =
        Config.path()
        |> File.read!()
        |> String.replace("  all_done:\n", "  all_done:\n    mode: redirect\n")

      tmp = write_tmp(config)

      assert_raise RuntimeError, ~r/requires a `redirect` block/, fn ->
        Config.load!(tmp)
      end
    end

    test "raises on an unknown placeholder in a redirect param" do
      config = String.replace(File.read!("priv/study/config.yml"), "%case_id%", "%foo%")
      tmp = write_tmp(config)

      assert_raise RuntimeError, ~r/unknown placeholder %foo%/, fn ->
        Config.load!(tmp)
      end
    end
  end

  defp write_tmp(contents) do
    path =
      Path.join(System.tmp_dir!(), "config_redirect_#{System.unique_integer([:positive])}.yml")

    File.write!(path, contents)
    on_exit(fn -> File.rm(path) end)
    path
  end

  describe "screens.pre_modification.skip" do
    test "can be enabled via config" do
      real_path = Config.path()

      tmp_path =
        Path.join(System.tmp_dir!(), "config_skip_#{System.unique_integer([:positive])}.yml")

      File.write!(
        tmp_path,
        real_path
        |> File.read!()
        |> String.replace("skip: false", "skip: true")
      )

      on_exit(fn ->
        File.rm(tmp_path)
        Config.load!(real_path)
      end)

      Config.load!(tmp_path)

      assert Config.skip_pre_modification?()
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

    test "rejects an item whose label override does not cover the full scale" do
      error =
        assert_raise RuntimeError, fn ->
          Config.load!("test/support/study/partial_item_labels_config.yml")
        end

      assert Exception.message(error) =~ "label per scale value"
    after
      # The failing load raises before caching, but reload the real config so any
      # later-ordered test still sees valid accessors.
      Config.reload()
    end

    test "reload/0 round-trips the real config without changing accessors" do
      title = Config.title()
      assert Config.reload()
      assert Config.title() == title
    end
  end
end
