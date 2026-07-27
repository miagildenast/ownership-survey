defmodule OwnershipAshChat.Study.Randomization do
  @moduledoc """
  Balanced nested-block randomization for the four writing runs (AGENTS.md, plan step #3)
  and for the modification variant (step #6).

  `topic_source` is the outer block, `ai_mode` the inner factor. A full draw is one of
  the 8 valid sequences — 2 `topic_source` orders × 2 `ai_mode` orders per block — and is
  fully described by three binary choices:

      {first_topic_source, first_ai_mode_of_block_1, first_ai_mode_of_block_2}

  ## Balanced, not independent coin flips

  Drawing every factor independently drifts badly at the sample sizes of this study (14
  sessions produced a 3 / 11 split on the modification variant). So a draw is **adaptive**:
  given how often each cell has been assigned so far, the least-used cell wins, and
  `Enum.random/1` only breaks a tie. On an empty database all counters are 0, every cell
  ties, and the draw is uniformly random; on a database that already drifted, the draw
  actively catches up.

  The counters are passed in (`OwnershipAshChat.Study.Balance` reads them from the
  database), which keeps this module pure apart from `Enum.random/1` and reading the
  configured assigned topic.

  Every draw also returns a **draw log** describing *why* the cell was picked — the input
  of the Telegram message built in `OwnershipAshChat.Notifications.Events`:

      %{chosen: {:free, :with_ai, :without_ai}, count: 0, tied: 1, others: {1, 3}, total: 14}

    * `count` — assignments of the chosen cell *before* this one
    * `tied` — how many cells shared the minimum (`1` = forced, `> 1` = random pick)
    * `others` — `{min, max}` over the remaining cells (`nil` when there are none)
    * `total` — assignments across all cells so far

  `:assigned` runs are seeded with the fixed study topic (`assigned_topic/0`);
  `:free` runs carry no topic — the participant's first line sets it implicitly.
  """

  alias OwnershipAshChat.Study.Types.Variant

  @topic_sources [:assigned, :free]
  @ai_modes [:with_ai, :without_ai]
  @default_assigned_topic "Jahreszeiten"

  # The 8 valid writing sequences, as {first_topic_source, ai_mode block 1, ai_mode block 2}.
  @sequences for topic_source <- @topic_sources,
                 block_1 <- @ai_modes,
                 block_2 <- @ai_modes,
                 do: {topic_source, block_1, block_2}

  @typedoc "One writing run's cell: the attrs needed to create a `kind: :writing` run."
  @type run_spec :: %{
          run_index: pos_integer(),
          kind: :writing,
          topic_source: :assigned | :free,
          ai_mode: :with_ai | :without_ai,
          topic: String.t() | nil
        }

  @typedoc "A writing sequence: which block came first, and which `ai_mode` led each block."
  @type sequence :: {:assigned | :free, :with_ai | :without_ai, :with_ai | :without_ai}

  @typedoc "Why a cell was picked — see the moduledoc."
  @type draw_log :: %{
          chosen: term(),
          count: non_neg_integer(),
          tied: pos_integer(),
          others: {non_neg_integer(), non_neg_integer()} | nil,
          total: non_neg_integer()
        }

  @doc "The 8 valid writing sequences."
  @spec sequences() :: [sequence()]
  def sequences, do: @sequences

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
  Draws one full plan: `{topic_source_order, run_specs, draw_log}`.

  `sequence_counts` maps a `sequence/0` to how often it has been assigned so far
  (`OwnershipAshChat.Study.Balance.writing_snapshot/0`); missing keys count as 0. The
  least-used sequence wins, ties are broken at random — so the default (no counts) is a
  uniform draw over all 8 sequences.

  `topic_source_order` is the block order (e.g. `[:free, :assigned]`), `run_specs` the
  four runs in presented order (`run_index` 1..4), `draw_log` the reason for the pick.
  """
  @spec draw_writing_plan(%{optional(sequence()) => non_neg_integer()}) ::
          {[:assigned | :free], [run_spec()], draw_log()}
  def draw_writing_plan(sequence_counts \\ %{}) do
    {{first_topic_source, _block_1, _block_2} = sequence, draw} =
      least_used(@sequences, sequence_counts)

    order = [first_topic_source, other(@topic_sources, first_topic_source)]

    specs =
      sequence
      |> expand_sequence()
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

    {order, specs, draw}
  end

  @doc """
  Expands a sequence into the four runs it stands for, as `{topic_source, ai_mode}` in
  presented order: both `ai_mode`s of the first block, then both of the second.
  """
  @spec expand_sequence(sequence()) :: [{:assigned | :free, :with_ai | :without_ai}]
  def expand_sequence({first_topic_source, block_1, block_2}) do
    [first_topic_source, other(@topic_sources, first_topic_source)]
    |> Enum.zip([block_1, block_2])
    |> Enum.flat_map(fn {topic_source, first_ai_mode} ->
      [{topic_source, first_ai_mode}, {topic_source, other(@ai_modes, first_ai_mode)}]
    end)
  end

  @doc """
  Draws the modification variant: `{variant, draw_log}`.

  `variant_counts` maps `:a` / `:b` to how often the variant has been assigned so far
  (`OwnershipAshChat.Study.Balance.variant_counts/1`); the rarer variant wins, ties are
  broken at random.
  """
  @spec draw_variant(%{optional(:a | :b) => non_neg_integer()}) :: {:a | :b, draw_log()}
  def draw_variant(variant_counts \\ %{}) do
    least_used(Variant.values(), variant_counts)
  end

  # Picks the least-used level (random tie-break) and describes the pick — see the
  # moduledoc for the shape of the draw log.
  defp least_used(levels, counts) do
    counted = Enum.map(levels, &{&1, Map.get(counts, &1, 0)})
    minimum = counted |> Enum.map(&elem(&1, 1)) |> Enum.min()
    tied = Enum.filter(counted, fn {_level, count} -> count == minimum end)
    {chosen, count} = Enum.random(tied)

    others =
      counted
      |> Enum.reject(fn {level, _count} -> level == chosen end)
      |> Enum.map(&elem(&1, 1))

    draw = %{
      chosen: chosen,
      count: count,
      tied: length(tied),
      others: if(others != [], do: {Enum.min(others), Enum.max(others)}),
      total: counted |> Enum.map(&elem(&1, 1)) |> Enum.sum()
    }

    {chosen, draw}
  end

  # The other of two levels.
  defp other(levels, level), do: levels |> List.delete(level) |> hd()
end
