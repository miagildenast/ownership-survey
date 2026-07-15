defmodule OwnershipAshChatWeb.DevStudyController do
  @moduledoc """
  Dev-only one-click entry into the study flow, bypassing the upstream `case_id` link.
  `new/2` starts a fresh session (which seeds 4 randomized writing runs), stashes its
  `session_id` in the Phoenix session, and drops the developer straight onto `/study`.

  Mounted under the `:dev_routes` compile flag only.
  """
  use OwnershipAshChatWeb, :controller

  alias OwnershipAshChat.Study

  def new(conn, _params) do
    case_id = "dev-#{System.unique_integer([:positive])}"
    case_number = "dev-#{System.unique_integer([:positive])}"
    session = Study.start_session!(%{case_id: case_id, case_number: case_number})

    conn
    |> put_session(:session_id, session.id)
    |> redirect(to: ~p"/study")
  end
end
