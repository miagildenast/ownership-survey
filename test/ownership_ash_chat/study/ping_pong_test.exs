defmodule OwnershipAshChat.Study.PingPongTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias OwnershipAshChat.Study.PingPong

  describe "first_line_prompt/1" do
    test "asks for the first German haiku line (5 syllables) on the topic" do
      prompt = PingPong.first_line_prompt("Jahreszeiten")

      assert prompt =~ "Generate the first line of a German haiku"
      assert prompt =~ "„Jahreszeiten“"
      assert prompt =~ "The line must contain EXACTLY 5 syllables."
      assert prompt =~ "Output language: German."
      assert prompt =~ "Return only the first line."
    end
  end

  describe "first_line_retry_prompt/3" do
    test "names the rejected line and its measured syllable count" do
      prompt = PingPong.first_line_retry_prompt("Jahreszeiten", "viel zu lange Zeile", 7)

      assert prompt =~ "„Jahreszeiten“"
      assert prompt =~ "„viel zu lange Zeile“"
      assert prompt =~ "had 7 syllables"
      assert prompt =~ "EXACTLY 5 syllables"
    end
  end

  describe "second_line_prompt/1" do
    test "asks for the second German haiku line and embeds line 1" do
      prompt = PingPong.second_line_prompt("Stille am Teich")

      assert prompt =~ "Generate the second line of a German haiku."
      assert prompt =~ "„Stille am Teich“"
      assert prompt =~ "The line must contain EXACTLY 7 syllables."
      assert prompt =~ "Output language: German."
      assert prompt =~ "Return only the second line."
    end
  end

  describe "lines/0" do
    test "a writing run holds three lines" do
      assert PingPong.lines() == 3
    end
  end

  describe "second_line_retry_prompt/3" do
    test "names the rejected line and its measured syllable count" do
      prompt = PingPong.second_line_retry_prompt("Alte Eiche", "viel zu lange Zeile hier", 9)

      assert prompt =~ "„Alte Eiche“"
      assert prompt =~ "„viel zu lange Zeile hier“"
      assert prompt =~ "had 9 syllables"
      assert prompt =~ "EXACTLY 7 syllables"
    end
  end

  describe "third_line_prompt/2" do
    test "asks for the third German haiku line (5 syllables) given lines 1 and 2" do
      prompt = PingPong.third_line_prompt("Stille am Teich", "Frösche springen ins Wasser")

      assert prompt =~ "Generate the third line of a German haiku."
      assert prompt =~ "„Stille am Teich“"
      assert prompt =~ "„Frösche springen ins Wasser“"
      assert prompt =~ "The line must contain EXACTLY 5 syllables."
      assert prompt =~ "Return only the third line."
    end
  end

  describe "third_line_retry_prompt/4" do
    test "names the rejected line and its measured syllable count" do
      prompt =
        PingPong.third_line_retry_prompt("Alte Eiche", "zweite Zeile", "viel zu lange Zeile", 7)

      assert prompt =~ "„Alte Eiche“"
      assert prompt =~ "„zweite Zeile“"
      assert prompt =~ "„viel zu lange Zeile“"
      assert prompt =~ "had 7 syllables"
      assert prompt =~ "EXACTLY 5 syllables"
    end
  end

  describe "generate_passage/2 line positions" do
    test "empty transcript: asks for the first line from the topic, 5-syllable target" do
      run = %{transcript: [], topic: "Jahreszeiten"}

      generator = fn prompt ->
        send(self(), {:prompt, prompt})
        "Stille an dem Teich"
      end

      assert {:ok, "Stille an dem Teich"} =
               PingPong.generate_passage(run, line_generator: generator)

      assert_received {:prompt, prompt}
      assert prompt =~ "Generate the first line of a German haiku"
      assert prompt =~ "„Jahreszeiten“"
      assert prompt =~ "EXACTLY 5 syllables"
    end

    test "first line rejected: retries against the 5-syllable target" do
      run = %{transcript: [], topic: "Jahreszeiten"}

      generator = fn prompt ->
        # base prompt → 7 syllables (invalid); retry prompt → 5 syllables (valid)
        if prompt =~ "previous attempt",
          do: "Stille an dem Teich",
          else: "Frösche springen ins Wasser"
      end

      assert {:ok, "Stille an dem Teich"} =
               PingPong.generate_passage(run, line_generator: generator)
    end

    test "two lines present: asks for the third line, 5-syllable target" do
      run = %{
        transcript: [
          %{"role" => "ai", "text" => "Stille an dem Teich"},
          %{"role" => "user", "text" => "Frösche springen ins Wasser"}
        ],
        topic: "Jahreszeiten"
      }

      generator = fn prompt ->
        send(self(), {:prompt, prompt})
        "Wasser klingt noch nach"
      end

      assert {:ok, "Wasser klingt noch nach"} =
               PingPong.generate_passage(run, line_generator: generator)

      assert_received {:prompt, prompt}
      assert prompt =~ "Generate the third line of a German haiku."
      assert prompt =~ "„Stille an dem Teich“"
      assert prompt =~ "„Frösche springen ins Wasser“"
      assert prompt =~ "EXACTLY 5 syllables"
    end
  end

  describe "generate_passage/2 validation loop" do
    @run %{transcript: [%{"role" => "user", "text" => "Alte Eiche"}]}

    test "retries with feedback until a valid 7-syllable line appears" do
      {:ok, agent} = Agent.start_link(fn -> 0 end)

      generator = fn prompt ->
        Agent.update(agent, &(&1 + 1))
        # base prompt → invalid (5 syllables); retry prompt → valid (7 syllables)
        if prompt =~ "previous attempt",
          do: "Frösche springen ins Wasser",
          else: "Stille an dem Teich"
      end

      assert {:ok, "Frösche springen ins Wasser"} =
               PingPong.generate_passage(@run, line_generator: generator)

      assert Agent.get(agent, & &1) == 2
    end

    test "falls back to the candidate closest to 7 syllables after max attempts" do
      generator = fn prompt ->
        # base → 5 syllables (distance 2); retries → 8 syllables (distance 1)
        if prompt =~ "previous attempt",
          do: "Frösche springen ins Wasser hin",
          else: "Stille an dem Teich"
      end

      {result, log} =
        with_log(fn -> PingPong.generate_passage(@run, line_generator: generator) end)

      assert {:fallback, "Frösche springen ins Wasser hin", candidates} = result
      assert log =~ "no valid 7-syllable line"

      assert length(candidates) == PingPong.line_attempts()
      assert List.first(candidates) == "Stille an dem Teich"
    end
  end

  describe "modification_prompt/3" do
    @haiku "alter Teich\nFrosch springt hinein\nWasserklang"

    test "variant :a asks for one word changed in the target line" do
      prompt = PingPong.modification_prompt(@haiku, :a, 0)

      assert prompt =~ @haiku
      assert prompt =~ "Change exactly one word in line 1."
      # Targets the participant's line, not the whole haiku.
      assert prompt =~ "alter Teich"
      # Line 1 carries the 5-syllable target so the reprompt loop has a goal.
      assert prompt =~ "EXACTLY 5 syllables"
    end

    test "variant :b asks for the target line replaced" do
      prompt = PingPong.modification_prompt(@haiku, :b, 1)

      assert prompt =~ @haiku
      assert prompt =~ "Replace line 2 entirely"
      assert prompt =~ "Frosch springt hinein"
      # Line 2 carries the 7-syllable target.
      assert prompt =~ "EXACTLY 7 syllables"
    end

    test "all variants restrict output to a single German line" do
      for variant <- [:a, :b] do
        prompt = PingPong.modification_prompt(@haiku, variant, 0)

        assert prompt =~ "a single line"
        assert prompt =~ "Output language: German."
      end
    end
  end

  describe "replace_line/3" do
    test "swaps only the target line, leaving the others byte-identical" do
      haiku = "alter Teich\nFrosch springt hinein\nWasserklang"

      assert PingPong.replace_line(haiku, 1, "Vogel singt am Ast") ==
               "alter Teich\nVogel singt am Ast\nWasserklang"
    end
  end

  describe "modification_retry_prompt/5" do
    @haiku "alter Teich\nFrosch springt hinein\nWasserklang"

    test "names the rejected line, its count, and the target for the given line" do
      prompt = PingPong.modification_retry_prompt(@haiku, :b, 1, "viel zu lang geraten hier", 9)

      assert prompt =~ "Replace line 2 entirely"
      assert prompt =~ "„viel zu lang geraten hier“ had 9 syllables"
      assert prompt =~ "EXACTLY 7 syllables"
      assert prompt =~ "Write a DIFFERENT version."
    end
  end

  describe "generate_modification/4 validation loop" do
    @haiku "alter Teich\nFrosch springt hinein\nWasserklang"

    test "validates the modified line against the target and retries with feedback" do
      {:ok, agent} = Agent.start_link(fn -> 0 end)

      generator = fn prompt ->
        Agent.update(agent, &(&1 + 1))
        # Line 0 → 5-syllable target. Base → 7 syllables (invalid); retry → 5 (valid).
        if prompt =~ "previous attempt",
          do: "Stille an dem Teich",
          else: "Frösche springen ins Wasser"
      end

      assert PingPong.generate_modification(@haiku, :a, 0, line_generator: generator) ==
               "Stille an dem Teich"

      assert Agent.get(agent, & &1) == 2
    end

    test "returns the closest candidate (a plain line, not a tuple) after max attempts" do
      generator = fn prompt ->
        # Line 1 → 7-syllable target. base → 5 (distance 2); retries → 8 (distance 1).
        if prompt =~ "previous attempt",
          do: "Frösche springen ins Wasser hin",
          else: "Stille an dem Teich"
      end

      {result, log} =
        with_log(fn ->
          PingPong.generate_modification(@haiku, :b, 1, line_generator: generator)
        end)

      assert result == "Frösche springen ins Wasser hin"
      assert log =~ "no valid 7-syllable line"
    end
  end
end
