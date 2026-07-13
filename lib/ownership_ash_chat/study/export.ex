defmodule OwnershipAshChat.Study.Export do
  @moduledoc """
  Serializes study `Session` records (with their loaded `runs`) into the on-demand
  JSON export artifact.

  JSON is not the storage format — it is produced from the `:export` / `:export_all`
  read actions (which load `runs`) and serialized here. Exported keys mirror the
  snake_case domain attribute names. Enum values are emitted as atoms, which `Jason`
  renders as strings.
  """

  alias OwnershipAshChat.Study.{Run, Session}

  # Sort key for a modification run (run_index is nil) — places it after all
  # writing runs, whose run_index is 1..4.
  @modification_order 1_000_000

  @doc "Build the plain export map for a single loaded session."
  def session_to_map(%Session{} = session) do
    %{
      session_id: session.id,
      case_id: session.case_id,
      status: session.status,
      topic_source_order: session.topic_source_order,
      started_at: session.started_at,
      completed_at: session.completed_at,
      metadata: session.metadata,
      runs: session.runs |> sort_runs() |> Enum.map(&run_to_map/1)
    }
  end

  @doc "Build the plain export map for a single run."
  def run_to_map(%Run{kind: :modification} = run) do
    Map.merge(writing_fields(run), %{
      variant: run.variant,
      source_run_index: run.source_run_index,
      modified_line_index: run.modified_line_index,
      original_haiku: run.original_haiku,
      modified_haiku: run.modified_haiku,
      open_answers: run.open_answers
    })
  end

  def run_to_map(%Run{} = run), do: writing_fields(run)

  @doc "Serialize one session (or a list of sessions) to a JSON string."
  def to_json(sessions) when is_list(sessions) do
    sessions |> Enum.map(&session_to_map/1) |> Jason.encode()
  end

  def to_json(%Session{} = session) do
    session |> session_to_map() |> Jason.encode()
  end

  @doc "Like `to_json/1` but raises on encoding errors."
  def to_json!(sessions) when is_list(sessions) do
    sessions |> Enum.map(&session_to_map/1) |> Jason.encode!()
  end

  def to_json!(%Session{} = session) do
    session |> session_to_map() |> Jason.encode!()
  end

  defp writing_fields(%Run{} = run) do
    %{
      run_index: run.run_index,
      kind: run.kind,
      topic_source: run.topic_source,
      ai_mode: run.ai_mode,
      topic: run.topic,
      transcript: run.transcript,
      final_haiku: run.final_haiku,
      likert: run.likert,
      started_at: run.started_at,
      completed_at: run.completed_at
    }
  end

  # Writing runs first, ordered by run_index; the modification run (run_index nil) last.
  defp sort_runs(runs) do
    Enum.sort_by(runs, fn run -> run.run_index || @modification_order end)
  end
end
