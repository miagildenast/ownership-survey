defmodule OwnershipAshChat.Study.SyllablesTest do
  use ExUnit.Case, async: true

  alias OwnershipAshChat.Study.Syllables

  describe "count_word/1" do
    test "counts vowel groups, treating diphthongs as one syllable" do
      # {word, expected}
      cases = [
        {"Teich", 1},
        {"Haus", 1},
        {"Baum", 1},
        {"Frosch", 1},
        {"Auge", 2},
        {"Freude", 2},
        {"Sonne", 2},
        {"Stille", 2},
        {"Wasserklang", 3},
        {"Nation", 3}
      ]

      for {word, expected} <- cases do
        assert Syllables.count_word(word) == expected,
               "expected #{word} to have #{expected} syllables, got #{Syllables.count_word(word)}"
      end
    end

    test "a word with no vowels counts 0" do
      assert Syllables.count_word("—") == 0
      assert Syllables.count_word("") == 0
    end

    test "ignores surrounding punctuation" do
      assert Syllables.count_word("Teich,") == 1
      assert Syllables.count_word("„Haus“") == 1
    end
  end

  describe "count/1" do
    test "sums the words of a line" do
      assert Syllables.count("Stille am Teich") == 4
    end

    test "recognises a valid 7-syllable line" do
      assert Syllables.count("Frösche springen ins Wasser") == 7
    end

    test "empty and whitespace-only lines count 0" do
      assert Syllables.count("") == 0
      assert Syllables.count("   ") == 0
    end

    test "counts double vowels (Schnee) as one syllable" do
      assert Syllables.count("im Schnee ver-sinkt der Mond") == 6
    end
  end
end
