defmodule OwnershipAshChat.Study.Stats do
  @moduledoc """
  Lean aggregate statistics over all study sessions — the monitoring counterpart to
  `OwnershipAshChat.Study.Export` (which dumps raw data).

  Answers four questions:

    * **How many questionnaires have been submitted so far?** — a run counts as
      submitted once its `likert` map is non-empty, split by run `kind`.
    * **How long do sessions take?** — median / min / max wall-clock duration
      (`completed_at - started_at`) over sessions that carry both timestamps.
    * **Is the randomization balanced?** — how often each `topic_source` block came
      first, and how often each `ai_mode` came first inside each of the two blocks.
    * **How were the haikus modified?** — how often the fifth run changed only one word
      (`variant: :a`) vs. the whole line (`variant: :b`).

  Computed in memory from the same `:export_all` read action the export uses (sessions
  with their `runs` loaded); the study's data volume is small enough that no aggregate
  queries are needed. Reached from three places:

    * `bin/export.sh stats` / `mix study.export --stats` (JSON artifact, see `to_json!/1`)
    * the daily notification (`OwnershipAshChat.Notifications.DailyReport`)
  """

  alias OwnershipAshChat.Study

  @statuses [:in_progress, :completed, :aborted]
  @topic_sources [:assigned, :free]
  @ai_modes [:with_ai, :without_ai]

  # Modification variants, under reporting names: `:a` rewrites a single word, `:b` the
  # whole target line (`Study.Types.Variant`).
  @variant_labels %{a: :one_word, b: :whole_line}

  # `run_index` of the first run of each topic_source block (4 writing runs, two per
  # block) — used to read back which ai_mode was drawn first within each block.
  @first_run_of_block %{1 => :block_1, 3 => :block_2}

  @doc "Load every session (with runs) and compute the statistics."
  def collect! do
    %{} |> Study.list_sessions_for_export!() |> compute()
  end

  @doc "Compute the statistics from an already-loaded list of sessions."
  def compute(sessions) when is_list(sessions) do
    %{
      generated_at: DateTime.utc_now(),
      sessions: session_counts(sessions),
      surveys: survey_counts(sessions),
      durations: durations(sessions),
      randomization: randomization(sessions),
      modifications: modification_counts(sessions)
    }
  end

  @doc "Serialize a statistics map to JSON."
  def to_json!(stats), do: Jason.encode!(stats)

  @doc """
  Render a duration in seconds as a compact human string (`"1h 4m 9s"`, `"18m 42s"`,
  `"7s"`). `nil` (no data) becomes `"n/a"`.
  """
  def humanize_duration(nil), do: "n/a"

  def humanize_duration(seconds) when is_number(seconds) do
    total = round(seconds)
    parts = [{div(total, 3600), "h"}, {rem(div(total, 60), 60), "m"}, {rem(total, 60), "s"}]

    case Enum.drop_while(parts, fn {value, _unit} -> value == 0 end) do
      [] -> "0s"
      kept -> Enum.map_join(kept, " ", fn {value, unit} -> "#{value}#{unit}" end)
    end
  end

  defp session_counts(sessions) do
    by_status = Enum.frequencies_by(sessions, & &1.status)

    @statuses
    |> Map.new(&{&1, Map.get(by_status, &1, 0)})
    |> Map.put(:total, length(sessions))
  end

  defp survey_counts(sessions) do
    submitted = sessions |> Enum.flat_map(&runs/1) |> Enum.filter(&submitted?/1)
    by_kind = Enum.frequencies_by(submitted, & &1.kind)

    %{
      submitted: length(submitted),
      writing: Map.get(by_kind, :writing, 0),
      modification: Map.get(by_kind, :modification, 0)
    }
  end

  # How the fifth run rewrote the participant's line, per variant. A modification run
  # carries its variant and the rewritten haiku from the moment it is inserted
  # (`Run.Changes.CreateModification`), so counting the records is enough.
  defp modification_counts(sessions) do
    counts =
      sessions
      |> Enum.flat_map(&runs/1)
      |> Enum.filter(&(&1.kind == :modification and &1.variant))
      |> Enum.frequencies_by(&@variant_labels[&1.variant])

    @variant_labels
    |> Map.values()
    |> Map.new(&{&1, Map.get(counts, &1, 0)})
    |> Map.put(:total, counts |> Map.values() |> Enum.sum())
  end

  defp durations(sessions) do
    seconds =
      sessions
      |> Enum.filter(&(&1.started_at && &1.completed_at))
      |> Enum.map(&DateTime.diff(&1.completed_at, &1.started_at))
      |> Enum.sort()

    %{
      sessions: length(seconds),
      median_seconds: median(seconds),
      min_seconds: List.first(seconds),
      max_seconds: List.last(seconds)
    }
  end

  defp randomization(sessions) do
    %{
      first_topic_source: first_topic_source_counts(sessions),
      first_ai_mode: first_ai_mode_counts(sessions)
    }
  end

  # Which topic_source block was presented first, read from the persisted draw.
  defp first_topic_source_counts(sessions) do
    counts =
      sessions
      |> Enum.map(&List.first(&1.topic_source_order || []))
      |> Enum.frequencies()

    Map.new(@topic_sources, &{&1, Map.get(counts, &1, 0)})
  end

  # Which ai_mode was drawn first inside each block, read from the first run of each
  # block (run_index 1 and 3).
  defp first_ai_mode_counts(sessions) do
    counts =
      for session <- sessions,
          run <- runs(session),
          block = @first_run_of_block[run.run_index],
          block && run.ai_mode,
          reduce: %{} do
        acc -> Map.update(acc, {block, run.ai_mode}, 1, &(&1 + 1))
      end

    Map.new(Map.values(@first_run_of_block), fn block ->
      {block, Map.new(@ai_modes, &{&1, Map.get(counts, {block, &1}, 0)})}
    end)
  end

  defp runs(%{runs: %Ash.NotLoaded{}} = session) do
    raise ArgumentError,
          "session #{session.id} has no runs loaded — compute/1 expects sessions from " <>
            "the :export / :export_all read actions"
  end

  defp runs(session), do: session.runs || []

  defp submitted?(run), do: map_size(run.likert || %{}) > 0

  # Expects a sorted list; even counts average the two middle values.
  defp median([]), do: nil

  defp median(sorted) do
    count = length(sorted)
    middle = div(count, 2)

    if rem(count, 2) == 1 do
      Enum.at(sorted, middle)
    else
      (Enum.at(sorted, middle - 1) + Enum.at(sorted, middle)) / 2
    end
  end
end
