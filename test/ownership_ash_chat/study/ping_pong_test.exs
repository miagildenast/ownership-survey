defmodule OwnershipAshChat.Study.PingPongTest do
  use ExUnit.Case, async: true

  alias OwnershipAshChat.Study.PingPong

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

      assert {:fallback, "Frösche springen ins Wasser hin", candidates} =
               PingPong.generate_passage(@run, line_generator: generator)

      assert length(candidates) == PingPong.line_attempts()
      assert List.first(candidates) == "Stille an dem Teich"
    end
  end

  describe "modification_prompt/2" do
    @haiku "alter Teich\nFrosch springt hinein\nWasserklang"

    test "variant :a asks for one word changed" do
      prompt = PingPong.modification_prompt(@haiku, :a)

      assert prompt =~ @haiku
      assert prompt =~ "Change exactly one word"
    end

    test "variant :b asks for one line replaced" do
      prompt = PingPong.modification_prompt(@haiku, :b)

      assert prompt =~ @haiku
      assert prompt =~ "Replace exactly one complete line"
    end

    test "variant :c asks for two lines replaced" do
      prompt = PingPong.modification_prompt(@haiku, :c)

      assert prompt =~ @haiku
      assert prompt =~ "Replace exactly two complete lines"
    end

    test "all variants constrain to 3 lines and German output" do
      for variant <- [:a, :b, :c] do
        prompt = PingPong.modification_prompt(@haiku, variant)

        assert prompt =~ "Keep exactly 3 lines."
        assert prompt =~ "Output language: German."
      end
    end
  end
end
