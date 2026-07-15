defmodule OwnershipAshChatWeb.StartController do
  @moduledoc """
  Token entry for the study. The upstream tool links participants here as
  `/start?case_id=…&case_number=…`. We resolve the `case_id` to a `Study.Session`
  (resuming an existing one if the participant returns), stash the `session_id` in the
  Phoenix session, and redirect to the study. A missing/blank `case_id` or `case_number`
  is rejected.
  """
  use OwnershipAshChatWeb, :controller

  alias OwnershipAshChat.Study

  def start(conn, params) do
    case_id = params |> Map.get("case_id", "") |> to_string() |> String.trim()
    case_number = params |> Map.get("case_number", "") |> to_string() |> String.trim()

    if case_id == "" or case_number == "" do
      conn
      |> put_flash(:error, "Missing or invalid access link.")
      |> redirect(to: ~p"/")
    else
      session = Study.start_session!(%{case_id: case_id, case_number: case_number})

      conn
      |> put_session(:session_id, session.id)
      |> redirect(to: ~p"/study")
    end
  end
end
