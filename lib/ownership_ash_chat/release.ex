defmodule OwnershipAshChat.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :ownership_ash_chat

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  @doc """
  Export study sessions as JSON.

  Starts the repo on its own (via `Ecto.Migrator.with_repo`), so it works under
  `bin/ownership_ash_chat eval` without the full app running. When the app is
  already up (prod), prefer calling `OwnershipAshChat.Study` + `Export` directly
  from `bin/ownership_ash_chat remote` instead of this helper.

  `selector` is one of:

    - `nil` — every session
    - a status atom (`:in_progress | :completed | :aborted`) — every session
      with that status
    - `{:session_id, id}` — the single session with that `session_id` (UUID)
    - `{:case_id, id}` — the single session with that `case_id`
    - `{:case_number, n}` — the single session with that `case_number`

  With `path`, writes the JSON to that file; without, returns the JSON string.
  """
  def export(path \\ nil, selector \\ nil) do
    load_app()
    [repo | _] = repos()

    {:ok, json, _} =
      Ecto.Migrator.with_repo(repo, fn _repo -> export_json(selector) end)

    case path do
      nil -> json
      path -> File.write!(path, json)
    end
  end

  defp export_json({:session_id, id}) do
    id |> OwnershipAshChat.Study.export_session!() |> OwnershipAshChat.Study.Export.to_json!()
  end

  defp export_json({:case_id, case_id}) do
    case_id
    |> OwnershipAshChat.Study.export_session_by_case_id!()
    |> OwnershipAshChat.Study.Export.to_json!()
  end

  defp export_json({:case_number, case_number}) do
    case_number
    |> OwnershipAshChat.Study.export_session_by_case_number!()
    |> OwnershipAshChat.Study.Export.to_json!()
  end

  defp export_json(status) do
    filter = if status, do: %{status: status}, else: %{}

    filter
    |> OwnershipAshChat.Study.list_sessions_for_export!()
    |> OwnershipAshChat.Study.Export.to_json!()
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
