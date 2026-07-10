defmodule OwnershipAshChat.Study.Randomization do
  @moduledoc """
  Nested-block randomization for the four writing runs (AGENTS.md, plan step #3).

  `topic_source` is the outer block, `ai_mode` the inner factor. One draw:

    1. the two `topic_source` values are put in random order;
    2. within each block the two `ai_mode` values are put in random order, so both
       `ai_mode`s of a block are presented back-to-back before switching block.

  This yields one of the 8 valid sequences (2 `topic_source` orders × 2 `ai_mode`
  orders per block). Pure apart from `Enum.shuffle/1` and reading the configured
  assigned topic; seed `:rand` in tests for determinism if needed.

  `:assigned` runs are seeded with the fixed study topic (`assigned_topic/0`);
  `:free` runs carry no topic — the participant's first line sets it implicitly.
  """

  @topic_sources [:assigned, :free]
  @ai_modes [:with_ai, :without_ai]
  @default_assigned_topic "Jahreszeiten"

  @typedoc "One writing run's cell: the attrs needed to create a `kind: :writing` run."
  @type run_spec :: %{
          run_index: pos_integer(),
          kind: :writing,
          topic_source: :assigned | :free,
          ai_mode: :with_ai | :without_ai,
          topic: String.t() | nil
        }

  @doc """
  The fixed topic every `:assigned` run gets. Developer-configurable via

      config :ownership_ash_chat, :study_assigned_topic, "Jahreszeiten"
  """
  @spec assigned_topic() :: String.t()
  def assigned_topic do
    Application.get_env(:ownership_ash_chat, :study_assigned_topic, @default_assigned_topic)
  end

  @doc """
  Picks the "best" writing run for the modification step (plan step #6).

  Best = highest average Likert score across all items (all positively coded, no
  reverse-scoring needed). On a tie the winner is chosen at random. Returns the run.
  """
  @spec best_run([map()]) :: map()
  def best_run(writing_runs) do
    runs_with_avg =
      Enum.map(writing_runs, fn run ->
        values = Map.values(run.likert || %{})
        avg = if values == [], do: 0.0, else: Enum.sum(values) / length(values)
        {run, avg}
      end)

    max_avg = runs_with_avg |> Enum.map(fn {_, avg} -> avg end) |> Enum.max()

    runs_with_avg
    |> Enum.filter(fn {_, avg} -> avg == max_avg end)
    |> Enum.random()
    |> elem(0)
  end

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
          ai_mode: ai_mode,
          topic: if(topic_source == :assigned, do: assigned_topic())
        }
      end)

    {order, specs}
  end
end
