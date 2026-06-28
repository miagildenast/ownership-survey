defmodule OwnershipAshChat.Study.Likert do
  @moduledoc """
  Definition of the post-run Likert questionnaire (plan step #5).

  Single source of truth for the items and the rating scale, shared by the
  `Run.submit_likert` action (via `Run.Validations.LikertAnswers`) and the UI.

  All items are **positively coded** (higher = better) so a run's answers can be
  averaged directly for the "best run" selection in step #6 — no reverse-scoring.

  The three items below are **placeholders** to fill the screen; the final wording
  and count are open question #5 in `AGENTS.md`. The scale is 5-point.

  Stored shape on `run.likert`: a map with the item keys as **strings** and
  integer values, e.g. `%{"zufriedenheit" => 5, "freude" => 4, "fluss" => 3}`
  (string keys mirror the embedded `transcript` maps and survive the JSON export).
  """

  @items [
    %{key: :zufriedenheit, prompt: "Ich bin mit dem entstandenen Haiku zufrieden."},
    %{key: :freude, prompt: "Das Schreiben hat mir Freude bereitet."},
    %{key: :fluss, prompt: "Ich konnte mühelos im Schreibfluss bleiben."}
  ]

  @scale 1..5

  @scale_labels %{
    1 => "Stimme gar nicht zu",
    2 => "Stimme eher nicht zu",
    3 => "Teils/teils",
    4 => "Stimme eher zu",
    5 => "Stimme voll zu"
  }

  @doc "The questionnaire items, in presentation order."
  def items, do: @items

  @doc "Item keys as atoms, in order."
  def keys, do: Enum.map(@items, & &1.key)

  @doc "Item keys as strings (the stored/exported form), in order."
  def string_keys, do: Enum.map(@items, &Atom.to_string(&1.key))

  @doc "The rating scale as a range (1..5)."
  def scale, do: @scale

  @doc "Map of scale value => human label."
  def scale_labels, do: @scale_labels
end
