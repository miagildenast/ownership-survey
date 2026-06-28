defmodule Mix.Tasks.Study.Export do
  @shortdoc "Exports study session(s) with their runs as JSON"

  @moduledoc """
  Exports study sessions (and their runs) to JSON — the on-demand export artifact.

  ## Usage

      # Single session by id, to stdout
      mix study.export <session_id>

      # All sessions
      mix study.export --all

      # All sessions with a given status (in_progress | completed | aborted)
      mix study.export --all --status completed

      # Write to a file instead of stdout
      mix study.export <session_id> --output session.json
      mix study.export --all -o sessions.json
  """

  use Mix.Task

  alias OwnershipAshChat.Study
  alias OwnershipAshChat.Study.Export

  @switches [all: :boolean, status: :string, output: :string]
  @aliases [o: :output]

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.start")

    {opts, args, _invalid} = OptionParser.parse(argv, switches: @switches, aliases: @aliases)

    json = build_json(opts, args)

    case opts[:output] do
      nil -> IO.puts(json)
      path -> File.write!(path, json)
    end
  end

  defp build_json(opts, args) do
    if opts[:all] do
      opts |> status_filter() |> Study.list_sessions_for_export!() |> Export.to_json!()
    else
      export_one(args)
    end
  end

  defp export_one([id]), do: id |> Study.export_session!() |> Export.to_json!()

  defp export_one(_),
    do: Mix.raise("Provide a single <session_id> or use --all. See `mix help study.export`.")

  defp status_filter(opts) do
    case opts[:status] do
      nil -> %{}
      status -> %{status: String.to_existing_atom(status)}
    end
  end
end
