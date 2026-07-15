defmodule OwnershipAshChatWeb.StartControllerTest do
  use OwnershipAshChatWeb.ConnCase, async: false

  defp case_id, do: "case-#{System.unique_integer([:positive])}"
  defp case_number, do: "num-#{System.unique_integer([:positive])}"

  defp params, do: %{case_id: case_id(), case_number: case_number()}

  describe "GET /start" do
    test "creates a session and redirects to the study flow", %{conn: conn} do
      conn = get(conn, ~p"/start?#{params()}")

      assert redirected_to(conn) == ~p"/study"
      assert get_session(conn, :session_id)
    end

    test "resumes the same session on re-entry with the same case_id" do
      p = params()

      id1 = get_session(get(build_conn(), ~p"/start?#{p}"), :session_id)
      id2 = get_session(get(build_conn(), ~p"/start?#{p}"), :session_id)

      assert id1 == id2
    end

    test "rejects a missing case_id", %{conn: conn} do
      conn = get(conn, ~p"/start?#{%{case_number: case_number()}}")

      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :session_id)
    end

    test "rejects a blank case_id", %{conn: conn} do
      conn = get(conn, ~p"/start?#{%{case_id: "   ", case_number: case_number()}}")

      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :session_id)
    end

    test "rejects a missing case_number", %{conn: conn} do
      conn = get(conn, ~p"/start?#{%{case_id: case_id()}}")

      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :session_id)
    end

    test "rejects a blank case_number", %{conn: conn} do
      conn = get(conn, ~p"/start?#{%{case_id: case_id(), case_number: "   "}}")

      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :session_id)
    end
  end
end
