defmodule OwnershipAshChatWeb.StartControllerTest do
  use OwnershipAshChatWeb.ConnCase, async: true

  defp case_id, do: "case-#{System.unique_integer([:positive])}"

  describe "GET /start" do
    test "creates a session and redirects to the landing", %{conn: conn} do
      conn = get(conn, ~p"/start?#{%{case_id: case_id()}}")

      assert redirected_to(conn) == ~p"/study/started"
      assert get_session(conn, :session_id)
    end

    test "resumes the same session on re-entry with the same case_id" do
      cid = case_id()

      id1 = get_session(get(build_conn(), ~p"/start?#{%{case_id: cid}}"), :session_id)
      id2 = get_session(get(build_conn(), ~p"/start?#{%{case_id: cid}}"), :session_id)

      assert id1 == id2
    end

    test "rejects a missing case_id", %{conn: conn} do
      conn = get(conn, ~p"/start")

      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :session_id)
    end

    test "rejects a blank case_id", %{conn: conn} do
      conn = get(conn, ~p"/start?#{%{case_id: "   "}}")

      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :session_id)
    end
  end

  describe "GET /study/started" do
    test "renders the stored session_id", %{conn: conn} do
      conn = get(conn, ~p"/start?#{%{case_id: case_id()}}")
      session_id = get_session(conn, :session_id)

      conn = get(conn, ~p"/study/started")
      assert html_response(conn, 200) =~ session_id
    end

    test "redirects when there is no active session", %{conn: conn} do
      conn = get(conn, ~p"/study/started")
      assert redirected_to(conn) == ~p"/"
    end
  end
end
