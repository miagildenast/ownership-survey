defmodule OwnershipAshChat.Study.Likert do
  @moduledoc """
  Accessors for the post-run Likert questionnaire and the modification-run
  open-ended questions.

  The items, scale and open questions are defined in the study configuration file
  (`priv/study/config.yml`) and read through `OwnershipAshChat.Study.Config`; this
  module adapts them to the shapes the UI and validations expect.

  All Likert items are **positively coded** (higher = better) so a run's answers can
  be averaged directly for the "best run" selection — no reverse-scoring.

  Stored shape on `run.likert`: a map with the item keys as **strings** and integer
  values, e.g. `%{"zufriedenheit" => 5}`. Open answers on `run.open_answers` follow
  the same string-keyed convention.
  """

  alias OwnershipAshChat.Study.Config

  @doc """
  The questionnaire items as `[%{key: atom, prompt: String.t(), labels: map | nil}]`,
  in order. `labels` is a per-item `value => label` override (covering the full
  scale) or `nil` to use the global `scale_labels/0`.
  """
  def items, do: Enum.map(Config.likert_items(), &to_item/1)

  @doc "Item keys as atoms, in order."
  def keys, do: Enum.map(Config.likert_items(), &String.to_atom(&1.key))

  @doc "Item keys as strings (the stored/exported form), in order."
  def string_keys, do: Enum.map(Config.likert_items(), & &1.key)

  @doc "The rating scale as a range (e.g. 1..5)."
  def scale, do: Config.likert_scale()

  @doc "Map of scale value => human label."
  def scale_labels, do: Config.likert_scale_labels()

  @doc "The open-ended questions (modification run) as `[%{key: atom, prompt:}]`."
  def open_questions, do: Enum.map(Config.open_questions(), &to_atom_keyed/1)

  @doc "Open-question keys as atoms, in order."
  def open_keys, do: Enum.map(Config.open_questions(), &String.to_atom(&1.key))

  @doc "Open-question keys as strings (the stored/exported form), in order."
  def open_string_keys, do: Enum.map(Config.open_questions(), & &1.key)

  defp to_item(%{key: key, prompt: prompt, labels: labels}),
    do: %{key: String.to_atom(key), prompt: prompt, labels: labels}

  defp to_atom_keyed(%{key: key, prompt: prompt}),
    do: %{key: String.to_atom(key), prompt: prompt}
end
