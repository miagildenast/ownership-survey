defmodule OwnershipAshChat.Study.Balance do
  @moduledoc """
  Reads the assignment counters `OwnershipAshChat.Study.Randomization` balances against.

  `Randomization` stays pure and takes the counters as input; this module is the thin
  database side of it. Both counters are computed in memory from lean read actions on
  `Run` (`:randomization_marks` / `:variant_marks`, which select a handful of columns and
  skip aborted sessions) — the study's data volume makes aggregate queries unnecessary,
  same reasoning as in `OwnershipAshChat.Study.Stats`.

  The two derivations mirror the ones the stats report uses, so the Telegram messages and
  the report can be read against each other: a session's writing sequence comes from its
  runs with `run_index` 1 and 3, the variant split from the `kind: :modification` runs.

  Not transactional: the counters are read just before the assignment is written, so two
  sessions starting in the very same moment can read the same counters and land on the
  same cell. Accepted — the study's participant frequency is far below that (and SQLite
  serializes the writes anyway); the next draw corrects the resulting imbalance.
  """

  alias OwnershipAshChat.Study
  alias OwnershipAshChat.Study.Types.Variant

  @topic_sources [:assigned, :free]
  @ai_modes [:with_ai, :without_ai]

  @doc """
  Everything a writing draw needs: how often each of the 8 sequences was assigned, the
  three marginal splits behind it, and how many sessions they cover.

      %{
        sequence_counts: %{{:free, :with_ai, :without_ai} => 3, …},
        marginals: %{
          topic: %{assigned: 5, free: 9},
          block_1: %{with_ai: 8, without_ai: 6},
          block_2: %{with_ai: 7, without_ai: 7}
        },
        sessions: 14
      }

  `sequence_counts` feeds `Randomization.draw_writing_plan/1`, `marginals` the reason line
  of the "session started" notification. Sessions missing run 1 or run 3 are skipped.
  """
  def writing_snapshot do
    sequences =
      Study.list_randomization_marks!()
      |> Enum.group_by(& &1.session_id)
      |> Enum.flat_map(&sequence/1)

    %{
      sequence_counts: Enum.frequencies(sequences),
      marginals: marginals(sequences),
      sessions: length(sequences)
    }
  end

  @doc "How often each modification variant was assigned: `%{a: 3, b: 11}`."
  def variant_counts do
    Study.list_variant_marks!() |> variants() |> counts(Variant.values())
  end

  @doc """
  One session's own modification variant plus the split *before* it was assigned:
  `{:a, %{a: 3, b: 11}}`. `{nil, counts}` when the session has no modification run yet.

  Used by the "session completed" notification to explain that session's variant. Both
  halves come out of a single read, which is why this isn't two `variant_counts/0` calls.
  """
  def variant_split(session_id) do
    {own, others} =
      Study.list_variant_marks!() |> Enum.split_with(&(&1.session_id == session_id))

    {own |> variants() |> List.first(), others |> variants() |> counts(Variant.values())}
  end

  # One session's drawn sequence, or `[]` when the session has no usable run 1 + run 3.
  defp sequence({_session_id, marks}) do
    by_index = Map.new(marks, &{&1.run_index, &1})
    first_block = by_index[1]
    second_block = by_index[3]

    if first_block && second_block && first_block.topic_source && first_block.ai_mode &&
         second_block.ai_mode do
      [{first_block.topic_source, first_block.ai_mode, second_block.ai_mode}]
    else
      []
    end
  end

  defp marginals(sequences) do
    %{
      topic: sequences |> Enum.map(&elem(&1, 0)) |> counts(@topic_sources),
      block_1: sequences |> Enum.map(&elem(&1, 1)) |> counts(@ai_modes),
      block_2: sequences |> Enum.map(&elem(&1, 2)) |> counts(@ai_modes)
    }
  end

  defp variants(marks), do: Enum.map(marks, & &1.variant)

  defp counts(values, levels) do
    frequencies = Enum.frequencies(values)

    Map.new(levels, &{&1, Map.get(frequencies, &1, 0)})
  end
end
