defmodule Mix.Tasks.Study.Export do
  @shortdoc "Exports study session(s) with their runs as JSON"

  @moduledoc """
  Exports study sessions (and their runs) to JSON — the on-demand export artifact.

  ## Usage

      # Single session by session_id (UUID), to stdout
      mix study.export --session-id <session_id>

      # Single session by case_id (the value handed out via /start?case_id=…)
      mix study.export --case-id <case_id>

      # All sessions
      mix study.export --all

      # All sessions with a given status (in_progress | completed | aborted)
      mix study.export --all --status completed

      # Write to a file instead of stdout
      mix study.export --session-id <session_id> --output session.json
      mix study.export --all -o sessions.json
  """

  use Mix.Task

  alias OwnershipAshChat.Study
  alias OwnershipAshChat.Study.Export

  @switches [
    all: :boolean,
    status: :string,
    output: :string,
    session_id: :string,
    case_id: :string
  ]
  @aliases [o: :output]

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.start")

    {opts, _args, _invalid} = OptionParser.parse(argv, switches: @switches, aliases: @aliases)

    json = build_json(opts)

    case opts[:output] do
      nil -> IO.puts(json)
      path -> File.write!(path, json)
    end
  end

  defp build_json(opts) do
    cond do
      opts[:all] ->
        opts |> status_filter() |> Study.list_sessions_for_export!() |> Export.to_json!()

      opts[:session_id] ->
        opts[:session_id] |> Study.export_session!() |> Export.to_json!()

      opts[:case_id] ->
        opts[:case_id] |> Study.export_session_by_case_id!() |> Export.to_json!()

      true ->
        usage_error()
    end
  end

  defp usage_error,
    do: Mix.raise("Provide --session-id, --case-id or --all. See `mix help study.export`.")

  defp status_filter(opts) do
    case opts[:status] do
      nil -> %{}
      status -> %{status: String.to_existing_atom(status)}
    end
  end
end
