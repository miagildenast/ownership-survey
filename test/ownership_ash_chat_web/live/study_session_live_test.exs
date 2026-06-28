defmodule OwnershipAshChatWeb.StudySessionLiveTest do
  use OwnershipAshChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import OwnershipAshChat.StudyGenerators

  alias OwnershipAshChat.Study

  # Build a session with two deterministic :without_ai writing runs and stash its id in
  # the session cookie, as StartController / the dev entry would.
  defp session_conn(conn) do
    session = generate(session())

    generate(
      run(session_id: session.id, run_index: 1, topic_source: :assigned, ai_mode: :without_ai)
    )

    generate(
      run(session_id: session.id, run_index: 2, topic_source: :assigned, ai_mode: :without_ai)
    )

    conn = Plug.Test.init_test_session(conn, %{session_id: session.id})
    {conn, session}
  end

  test "redirects to / when no session cookie is set", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/study")
  end

  test "shows the first run and advances to the next on Weiter", %{conn: conn} do
    {conn, _session} = session_conn(conn)

    {:ok, view, html} = live(conn, ~p"/study")
    assert html =~ "Run 1 von 2"

    # Complete run 1 (three human lines → auto-completes).
    for line <- ["alter Teich", "Frosch springt hinein", "Wasserklang"] do
      view
      |> form("form[phx-submit=add_passage]", %{"text" => line})
      |> render_submit()
    end

    # Run complete: the assembled haiku and the Weiter button are shown.
    rendered = render(view)
    assert rendered =~ "alter Teich\nFrosch springt hinein\nWasserklang"
    assert rendered =~ "Weiter"

    # Advance to run 2.
    view |> element("button", "Weiter") |> render_click()
    assert render(view) =~ "Run 2 von 2"
  end

  test "shows the end card once all runs are complete", %{conn: conn} do
    session = generate(session())
    run = generate(run(session_id: session.id, run_index: 1, ai_mode: :without_ai))

    # Pre-complete the only run.
    Enum.reduce(["eins", "zwei", "drei"], run, fn line, run ->
      Study.add_user_passage!(run, line)
    end)

    conn = Plug.Test.init_test_session(conn, %{session_id: session.id})

    {:ok, _view, html} = live(conn, ~p"/study")
    assert html =~ "Alle Runs abgeschlossen"
    assert html =~ session.id
  end
end
