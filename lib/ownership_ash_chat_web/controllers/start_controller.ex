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
        |> redirect(to: ~p"/study/started")
    end
  end

  def show(conn, _params) do
    case get_session(conn, :session_id) do
      nil ->
        conn
        |> put_flash(:error, "No active study session. Please use your access link.")
        |> redirect(to: ~p"/")

      session_id ->
        render(conn, :started, session_id: session_id)
    end
  end
end
