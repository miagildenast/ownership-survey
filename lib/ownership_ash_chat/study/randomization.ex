defmodule OwnershipAshChat.Study.Randomization do
  @moduledoc """
  Nested-block randomization for the four writing runs (AGENTS.md, plan step #3).

  `topic_source` is the outer block, `ai_mode` the inner factor. One draw:

    1. the two `topic_source` values are put in random order;
    2. within each block the two `ai_mode` values are put in random order, so both
       `ai_mode`s of a block are presented back-to-back before switching block.

  This yields one of the 8 valid sequences (2 `topic_source` orders × 2 `ai_mode`
  orders per block). Pure — the only effect is `Enum.shuffle/1`; seed `:rand` in tests
  for determinism if needed.
  """

  @topic_sources [:assigned, :free]
  @ai_modes [:with_ai, :without_ai]

  @typedoc "One writing run's cell: the attrs needed to create a `kind: :writing` run."
  @type run_spec :: %{
          run_index: pos_integer(),
          kind: :writing,
          topic_source: :assigned | :free,
          ai_mode: :with_ai | :without_ai
        }

  @doc """
  Draws one full plan: `{topic_source_order, run_specs}`.

  `topic_source_order` is the randomized block order (e.g. `[:free, :assigned]`).
  `run_specs` is the four runs in presented order, `run_index` 1..4.
  """
  @spec draw_writing_plan() :: {[:assigned | :free], [run_spec()]}
  def draw_writing_plan do
    order = Enum.shuffle(@topic_sources)

    specs =
      order
      |> Enum.flat_map(fn topic_source ->
        Enum.map(Enum.shuffle(@ai_modes), &{topic_source, &1})
      end)
      |> Enum.with_index(1)
      |> Enum.map(fn {{topic_source, ai_mode}, run_index} ->
        %{
          run_index: run_index,
          kind: :writing,
          topic_source: topic_source,
          ai_mode: ai_mode
        }
      end)

    {order, specs}
  end
end
