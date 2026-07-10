defmodule OwnershipAshChatWeb.StudySessionLiveTest do
  use OwnershipAshChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import OwnershipAshChat.StudyGenerators

  alias OwnershipAshChat.Study

  # Build a session with a deterministic :without_ai run followed by an
  # :assigned/:with_ai run, and stash its id in the session cookie, as
  # StartController / the dev entry would.
  defp session_conn(conn) do
    session = generate(session())

    generate(
      run(
        session_id: session.id,
        run_index: 1,
        topic_source: :assigned,
        ai_mode: :without_ai,
        topic: "Jahreszeiten"
      )
    )

    generate(
      run(
        session_id: session.id,
        run_index: 2,
        topic_source: :assigned,
        ai_mode: :with_ai,
        topic: "Jahreszeiten"
      )
    )

    conn = Plug.Test.init_test_session(conn, %{session_id: session.id})
    {conn, session}
  end

  # Stub that returns the original haiku with " (modified)" appended to avoid live LLM calls.
  def stub_modification(haiku, _variant, _opts), do: haiku <> " (modified)"

  test "redirects to / when no session cookie is set", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/study")
  end

  test "shows the first run and advances to the next on Weiter", %{conn: conn} do
    {conn, _session} = session_conn(conn)

    {:ok, view, html} = live(conn, ~p"/study")
    assert html =~ "Run 1 von 2"
    # The assigned topic is displayed.
    assert html =~ "Jahreszeiten"

    # Complete run 1 (three human lines → auto-completes).
    for line <- ["alter Teich", "Frosch springt hinein", "Wasserklang"] do
      view
      |> form("form[phx-submit=add_passage]", %{"text" => line})
      |> render_submit()
    end

    # Writing done: the assembled haiku and the questionnaire are shown, but not Weiter yet.
    rendered = render(view)
    assert rendered =~ "alter Teich\nFrosch springt hinein\nWasserklang"
    assert rendered =~ "Fragebogen"
    refute rendered =~ "Weiter"

    # Answer the Likert questionnaire → the Weiter button appears.
    view
    |> form("#likert-form", %{
      "likert" => %{"zufriedenheit" => "5", "freude" => "4", "fluss" => "3"}
    })
    |> render_submit()

    assert render(view) =~ "Weiter"

    # Advance to run 2 (:assigned/:with_ai): the AI's opening line is generated on
    # entry and shown before any input.
    view |> element("button", "Weiter") |> render_click()
    rendered = render(view)
    assert rendered =~ "Run 2 von 2"
    assert rendered =~ OwnershipAshChat.Study.PingPongStub.text()

    # One human line (line 2) completes the run — the AI closes with line 3.
    view
    |> form("form[phx-submit=add_passage]", %{"text" => "Frosch springt hinein"})
    |> render_submit()

    assert render(view) =~ "Fragebogen"
  end

  test "shows pre_modification transition card after all writing runs complete", %{conn: conn} do
    Application.put_env(
      :ownership_ash_chat,
      :study_modification_responder,
      {__MODULE__, :stub_modification}
    )

    on_exit(fn ->
      Application.delete_env(:ownership_ash_chat, :study_modification_responder)
    end)

    session = generate(session())
    run1 = generate(run(session_id: session.id, run_index: 1, ai_mode: :without_ai))

    completed =
      Enum.reduce(["eins", "zwei", "drei"], run1, fn line, r ->
        Study.add_user_passage!(r, line)
      end)

    Study.submit_likert!(completed, %{
      likert: %{"zufriedenheit" => 5, "freude" => 4, "fluss" => 3}
    })

    conn = Plug.Test.init_test_session(conn, %{session_id: session.id})
    {:ok, view, html} = live(conn, ~p"/study")

    # Only one writing run, it's done → transition card
    assert html =~ "Schreibphase abgeschlossen"
    assert html =~ "Weiter"
    refute html =~ "Studie abgeschlossen"

    # Clicking Weiter creates the modification run
    view |> element("button", "Weiter") |> render_click()

    rendered = render(view)
    assert rendered =~ "Modifikations-Run"
    assert rendered =~ "Original-Haiku"
    assert rendered =~ "Modifiziertes Haiku"
    assert rendered =~ "(modified)"
    assert rendered =~ "Fragebogen"
  end

  test "modification run Likert → Weiter → end screen, session :completed", %{conn: conn} do
    Application.put_env(
      :ownership_ash_chat,
      :study_modification_responder,
      {__MODULE__, :stub_modification}
    )

    on_exit(fn ->
      Application.delete_env(:ownership_ash_chat, :study_modification_responder)
    end)

    session = generate(session())
    run1 = generate(run(session_id: session.id, run_index: 1, ai_mode: :without_ai))

    completed =
      Enum.reduce(["eins", "zwei", "drei"], run1, fn line, r ->
        Study.add_user_passage!(r, line)
      end)

    Study.submit_likert!(completed, %{
      likert: %{"zufriedenheit" => 5, "freude" => 4, "fluss" => 3}
    })

    conn = Plug.Test.init_test_session(conn, %{session_id: session.id})
    {:ok, view, _html} = live(conn, ~p"/study")

    # Advance to modification run
    view |> element("button", "Weiter") |> render_click()
    assert render(view) =~ "Modifikations-Run"

    # Submit Likert for modification run → Weiter appears
    view
    |> form("#likert-form", %{
      "likert" => %{"zufriedenheit" => "4", "freude" => "4", "fluss" => "4"}
    })
    |> render_submit()

    assert render(view) =~ "Weiter"

    # Weiter → end screen
    view |> element("button", "Weiter") |> render_click()

    rendered = render(view)
    assert rendered =~ "Studie abgeschlossen"
    assert rendered =~ session.id

    # Session must be :completed in the database
    reloaded = Study.get_session!(session.id)
    assert reloaded.status == :completed
    refute is_nil(reloaded.completed_at)
  end

  test "flash 'picked randomly' shown when multiple runs tie on Likert average", %{conn: conn} do
    Application.put_env(
      :ownership_ash_chat,
      :study_modification_responder,
      {__MODULE__, :stub_modification}
    )

    on_exit(fn ->
      Application.delete_env(:ownership_ash_chat, :study_modification_responder)
    end)

    session = generate(session())

    # Two runs with identical Likert scores → tie.
    for idx <- [1, 2] do
      r = generate(run(session_id: session.id, run_index: idx, ai_mode: :without_ai))

      completed =
        Enum.reduce(["eins", "zwei", "drei"], r, fn line, run ->
          Study.add_user_passage!(run, line)
        end)

      Study.submit_likert!(completed, %{
        likert: %{"zufriedenheit" => 4, "freude" => 4, "fluss" => 4}
      })
    end

    conn = Plug.Test.init_test_session(conn, %{session_id: session.id})
    {:ok, view, _html} = live(conn, ~p"/study")

    assert render(view) =~ "Schreibphase abgeschlossen"

    view |> element("button", "Weiter") |> render_click()

    assert render(view) =~ "picked randomly"
  end

  test "shows the end card once all runs are complete (legacy: no modification run)", %{
    conn: conn
  } do
    session = generate(session())
    run = generate(run(session_id: session.id, run_index: 1, ai_mode: :without_ai))

    # Pre-complete the only run: write its lines, then answer the questionnaire.
    completed =
      Enum.reduce(["eins", "zwei", "drei"], run, fn line, run ->
        Study.add_user_passage!(run, line)
      end)

    Study.submit_likert!(completed, %{
      likert: %{"zufriedenheit" => 5, "freude" => 4, "fluss" => 3}
    })

    conn = Plug.Test.init_test_session(conn, %{session_id: session.id})

    {:ok, _view, html} = live(conn, ~p"/study")
    # With no modification run yet we expect the transition card.
    assert html =~ "Schreibphase abgeschlossen"
  end
end
