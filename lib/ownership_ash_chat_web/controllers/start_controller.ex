defmodule OwnershipAshChatWeb.StartController do
  @moduledoc """
  Token entry for the study. The upstream tool links participants here as
  `/start?case_id=…`. We resolve the `case_id` to a `Study.Session` (resuming an
  existing one if the participant returns), stash the `session_id` in the Phoenix
  session, and redirect to the study. A missing/blank `case_id` is rejected.
  """
  use OwnershipAshChatWeb, :controller

  alias OwnershipAshChat.Study

  def start(conn, params) do
    case params |> Map.get("case_id", "") |> to_string() |> String.trim() do
      "" ->
        conn
        |> put_flash(:error, "Missing or invalid access link.")
        |> redirect(to: ~p"/")

      case_id ->
        session = Study.start_session!(%{case_id: case_id})

        conn
        |> put_session(:session_id, session.id)
        |> redirect(to: ~p"/study")
    end
  end
end
