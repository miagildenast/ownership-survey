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
