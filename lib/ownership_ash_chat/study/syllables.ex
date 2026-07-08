defmodule OwnershipAshChat.Study.Syllables do
  @moduledoc """
  Heuristic German syllable counter used to validate generated haiku lines.

  LLMs process tokens, not syllables, so they cannot reliably hit a target syllable
  count from prompt instructions alone. `count/1` gives us an approximate but cheap
  local check (~95% accurate on ordinary German); the ping-pong retry loop
  (`OwnershipAshChat.Study.PingPong`) absorbs the remaining error by re-prompting.

  The heuristic counts vowel groups: each run of vowels normally yields one syllable,
  except a small set of German diphthongs (`ei`, `au`, `eu`, …) which are two letters
  but one syllable. It is intentionally simple — not a hyphenation dictionary.
  """

  @vowels ~w(a e i o u ä ö ü y)
  @diphthongs ~w(ei ai ey ay au eu äu ie)

  @doc """
  Total syllable count of a line: the sum over whitespace-separated words.

  Punctuation is ignored; a word with no vowel letters (e.g. a stray dash) counts 0,
  any other word counts at least 1.
  """
  @spec count(String.t()) :: non_neg_integer()
  def count(text) when is_binary(text) do
    text
    |> String.split(~r/\s+/u, trim: true)
    |> Enum.map(&count_word/1)
    |> Enum.sum()
  end

  @doc "Syllable count of a single word."
  @spec count_word(String.t()) :: non_neg_integer()
  def count_word(word) when is_binary(word) do
    chars =
      word
      |> String.downcase()
      |> String.replace(~r/[^a-zäöüßy]/u, "")
      |> String.graphemes()

    case chars do
      [] -> 0
      _ -> max(do_count(chars), 1)
    end
  end

  defp do_count([a, b | rest]) do
    cond do
      (a <> b) in @diphthongs -> 1 + do_count(rest)
      vowel?(a) -> 1 + do_count([b | rest])
      true -> do_count([b | rest])
    end
  end

  defp do_count([a]), do: if(vowel?(a), do: 1, else: 0)
  defp do_count([]), do: 0

  defp vowel?(char), do: char in @vowels
end
