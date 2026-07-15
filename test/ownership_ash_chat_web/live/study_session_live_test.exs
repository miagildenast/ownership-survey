defmodule OwnershipAshChatWeb.StudySessionLiveTest do
  use OwnershipAshChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import OwnershipAshChat.StudyGenerators

  alias OwnershipAshChat.Study
  alias OwnershipAshChat.Study.Config

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

  # Stub returning a single new line (the enhanced line) to avoid live LLM calls.
  def stub_modification(_haiku, _variant, _line_index, _opts), do: "veränderte Zeile (modified)"

  test "redirects to / when no session cookie is set", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/study")
  end

  test "intro → Start → runs 1+2, Likert advances directly to the next run", %{conn: conn} do
    {conn, _session} = session_conn(conn)

    {:ok, view, html} = live(conn, ~p"/study")

    # Fresh session → intro with instructions and Start button, no chat form yet.
    assert html =~ "Willkommen zur Studie"
    assert has_element?(view, "#start-btn")
    refute has_element?(view, "#passage-form")

    # Start begins run 1 (:assigned/:without_ai): chat with the topic task message.
    view |> element("#start-btn") |> render_click()
    rendered = render(view)
    assert rendered =~ "Run 1 von 2"
    assert rendered =~ "Jahreszeiten"
    refute has_element?(view, "#start-btn")

    # Complete run 1 (three human lines → auto-completes). Each line is shown
    # optimistically and persisted async, so await the async result.
    for line <- ["alter Teich", "Frosch springt hinein", "Wasserklang"] do
      view
      |> form("#passage-form", %{"text" => line})
      |> render_submit()

      render_async(view)
    end

    # Writing done → full-screen Likert: haiku + questionnaire, no chat form.
    rendered = render(view)
    assert rendered =~ "alter Teich\nFrosch springt hinein\nWasserklang"
    assert rendered =~ "Fragebogen"
    refute has_element?(view, "#passage-form")

    # Submitting the Likert advances directly into run 2 (:assigned/:with_ai):
    # the AI's opening line is generated on entry and shown before any input.
    view
    |> form("#likert-form", %{
      "likert" => %{"zufriedenheit" => "5", "freude" => "4", "fluss" => "3"}
    })
    |> render_submit()

    rendered = render(view)
    assert rendered =~ "Run 2 von 2"
    assert rendered =~ OwnershipAshChat.Study.PingPongStub.text()
    refute has_element?(view, "#likert-form")

    # One human line (line 2) completes the run — the AI closes with line 3.
    view
    |> form("#passage-form", %{"text" => "Frosch springt hinein"})
    |> render_submit()

    # The pending line shows immediately, before the AI reply landed.
    assert render(view) =~ "Frosch springt hinein"

    render_async(view)
    assert render(view) =~ "Fragebogen"
  end

  test "resumes into the chat (no intro) once the first run has begun", %{conn: conn} do
    {conn, session} = session_conn(conn)

    # Begin run 1 as the Start click would, then reload the page.
    session
    |> then(&Study.get_session!(&1.id, load: [:runs]))
    |> Map.get(:runs)
    |> Enum.find(&(&1.run_index == 1))
    |> Study.begin_run!()

    {:ok, view, html} = live(conn, ~p"/study")

    refute has_element?(view, "#start-btn")
    assert has_element?(view, "#passage-form")
    assert html =~ "Run 1 von 2"
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
    assert has_element?(view, "#weiter-btn")
    refute html =~ "Studie abgeschlossen"

    # Clicking Weiter creates the modification run → full-screen Likert showing
    # only the modified haiku (no comparison, no debug info).
    view |> element("#weiter-btn") |> render_click()

    rendered = render(view)
    assert rendered =~ "(modified)"
    assert rendered =~ "Fragebogen"
    assert has_element?(view, "#likert-form")
    refute rendered =~ "Original-Haiku"
    refute rendered =~ "Modifiziertes Haiku"
    refute rendered =~ "Modifikations-Run"
  end

  test "screens.pre_modification.skip auto-creates the modification run, no transition card",
       %{conn: conn} do
    Application.put_env(
      :ownership_ash_chat,
      :study_modification_responder,
      {__MODULE__, :stub_modification}
    )

    real_config_path = Config.path()

    tmp_config_path =
      Path.join(System.tmp_dir!(), "config_skip_#{System.unique_integer([:positive])}.yml")

    File.write!(
      tmp_config_path,
      real_config_path
      |> File.read!()
      |> String.replace("skip: false", "skip: true")
    )

    Config.load!(tmp_config_path)

    on_exit(fn ->
      Application.delete_env(:ownership_ash_chat, :study_modification_responder)
      File.rm(tmp_config_path)
      Config.load!(real_config_path)
    end)

    session = generate(session())
    run1 = generate(run(session_id: session.id, run_index: 1, ai_mode: :without_ai))

    completed =
      Enum.reduce(["eins", "zwei", "drei"], run1, fn line, r ->
        Study.add_user_passage!(r, line)
      end)

    Study.submit_likert!(completed, %{
      likert: Map.new(Config.likert_items(), &{&1.key, 5})
    })

    conn = Plug.Test.init_test_session(conn, %{session_id: session.id})
    {:ok, view, html} = live(conn, ~p"/study")

    # Straight to the modification run's Likert — no transition card, no click.
    refute has_element?(view, "#weiter-btn")
    refute html =~ "Schreibphase abgeschlossen"
    assert html =~ "(modified)"
    assert html =~ "Fragebogen"
    assert has_element?(view, "#likert-form")
  end

  test "modification run Likert submits straight to the end screen, session :completed", %{
    conn: conn
  } do
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

    # Advance to the modification run's Likert screen.
    view |> element("#weiter-btn") |> render_click()
    assert has_element?(view, "#likert-form")

    # The modification run additionally asks the configured open-ended questions.
    assert has_element?(view, "textarea[name='open_answers[begruendung]']")
    assert has_element?(view, "textarea[name='open_answers[anmerkungen]']")

    # Submitting its Likert + open answers finishes the study → end screen.
    view
    |> form("#likert-form", %{
      "likert" => %{"zufriedenheit" => "4", "freude" => "4", "fluss" => "4"},
      "open_answers" => %{"begruendung" => "Klingt runder.", "anmerkungen" => "Keine."}
    })
    |> render_submit()

    rendered = render(view)
    assert rendered =~ Config.screen(:all_done).heading
    assert rendered =~ session.id

    # Session must be :completed in the database, with the open answers stored.
    reloaded = Study.get_session!(session.id, load: [:runs])
    assert reloaded.status == :completed
    refute is_nil(reloaded.completed_at)

    mod_run = Enum.find(reloaded.runs, &(&1.kind == :modification))
    assert mod_run.open_answers == %{"begruendung" => "Klingt runder.", "anmerkungen" => "Keine."}
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

  describe "all_done end screen modes" do
    test "copy mode (fixture) renders the session UUID and copy button" do
      html =
        render_component(&OwnershipAshChatWeb.StudyComponents.all_done_screen/1,
          session_id: "sess-123",
          case_id: "case-9"
        )

      assert html =~ "sess-123"
      assert html =~ "copy-session-id"
      refute html =~ "sosci.uni-hamburg.de"
    end

    test "redirect mode renders a return link with substituted params and no UUID" do
      # Build a self-contained redirect config on top of the copy-mode fixture so the
      # assertions don't depend on the real priv/study/config.yml values.
      fixture = Config.path()
      on_exit(fn -> Config.load!(fixture) end)

      redirect_all_done = """
        all_done:
          mode: redirect
          redirect:
            url: "https://example.test/return/"
            button_label: "Zurück zum Test"
            params:
              - key: i
                value: "%case_id%"
      """

      config = String.replace(File.read!(fixture), "  all_done:\n", redirect_all_done)

      tmp =
        Path.join(System.tmp_dir!(), "config_redirect_#{System.unique_integer([:positive])}.yml")

      File.write!(tmp, config)
      on_exit(fn -> File.rm(tmp) end)
      Config.load!(tmp)

      html =
        render_component(&OwnershipAshChatWeb.StudyComponents.all_done_screen/1,
          session_id: "sess-123",
          case_id: "case-9"
        )

      assert html =~ ~s(href="https://example.test/return/?i=case-9")
      assert html =~ "Zurück zum Test"
      refute html =~ "copy-session-id"
      refute html =~ "sess-123"
    end
  end
end
