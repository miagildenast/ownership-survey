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
end
