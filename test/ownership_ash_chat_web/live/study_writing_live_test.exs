defmodule OwnershipAshChatWeb.StudyWritingLiveTest do
  use OwnershipAshChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import OwnershipAshChat.StudyGenerators

  alias OwnershipAshChat.Study

  test "renders the run and records a submitted passage", %{conn: conn} do
    run = generate(run(topic_source: :free, ai_mode: :without_ai))

    {:ok, view, html} = live(conn, ~p"/dev/study/run/#{run.id}")

    assert html =~ "Schreib-Run"
    # :free runs have no topic step — the first line sets the topic implicitly.
    refute html =~ "Thema"

    view
    |> form("form[phx-submit=add_passage]", %{"text" => "Stille am Teich"})
    |> render_submit()

    assert render(view) =~ "Stille am Teich"

    reloaded = Study.get_run!(run.id)
    assert [%{"role" => "user", "text" => "Stille am Teich"}] = reloaded.transcript
    # Mounting began the run.
    refute is_nil(reloaded.started_at)
  end

  test "assigned/with_ai shows the topic and the AI's opening line on mount", %{conn: conn} do
    run = generate(run(topic_source: :assigned, ai_mode: :with_ai, topic: "Jahreszeiten"))

    {:ok, view, html} = live(conn, ~p"/dev/study/run/#{run.id}")

    assert html =~ "Jahreszeiten"
    assert html =~ OwnershipAshChat.Study.PingPongStub.text()

    # The participant's single line (line 2) completes the run: AI closes with line 3.
    view
    |> form("form[phx-submit=add_passage]", %{"text" => "Frosch springt hinein"})
    |> render_submit()

    reloaded = Study.get_run!(run.id)
    assert Enum.map(reloaded.transcript, & &1["role"]) == ["ai", "user", "ai"]
    refute is_nil(reloaded.completed_at)
    refute render(view) =~ "phx-submit=\"add_passage\""
  end

  test "renders a fallback note with the tried candidates when the AI gives up", %{conn: conn} do
    Application.put_env(
      :ownership_ash_chat,
      :study_responder,
      {OwnershipAshChat.Study.FallbackResponder, :reply}
    )

    on_exit(fn ->
      Application.put_env(
        :ownership_ash_chat,
        :study_responder,
        {OwnershipAshChat.Study.PingPongStub, :reply}
      )
    end)

    run = generate(run(ai_mode: :with_ai))

    {:ok, view, _html} = live(conn, ~p"/dev/study/run/#{run.id}")

    view
    |> form("form[phx-submit=add_passage]", %{"text" => "Stille am Teich"})
    |> render_submit()

    html = render(view)
    assert html =~ "KI konnte nicht zuverlässig eine Zeile generieren"
    assert html =~ "Kurze Zeile, Andere Zeile"
  end

  test "the run auto-completes and assembles its haiku after three lines", %{conn: conn} do
    run = generate(run(ai_mode: :without_ai))

    {:ok, view, _html} = live(conn, ~p"/dev/study/run/#{run.id}")

    for line <- ["alter Teich", "Frosch springt hinein", "Wasserklang"] do
      view
      |> form("form[phx-submit=add_passage]", %{"text" => line})
      |> render_submit()
    end

    reloaded = Study.get_run!(run.id)
    assert reloaded.final_haiku == "alter Teich\nFrosch springt hinein\nWasserklang"
    refute is_nil(reloaded.completed_at)

    # Writing phase is closed — no more passage form.
    refute render(view) =~ "phx-submit=\"add_passage\""
  end

  test "the questionnaire appears after completion and persists the answers", %{conn: conn} do
    run = generate(run(ai_mode: :without_ai))

    {:ok, view, _html} = live(conn, ~p"/dev/study/run/#{run.id}")

    # Complete the writing phase so the questionnaire is shown.
    for line <- ["alter Teich", "Frosch springt hinein", "Wasserklang"] do
      view
      |> form("form[phx-submit=add_passage]", %{"text" => line})
      |> render_submit()
    end

    assert render(view) =~ "Fragebogen"

    view
    |> form("#likert-form", %{
      "likert" => %{"zufriedenheit" => "5", "freude" => "4", "fluss" => "3"}
    })
    |> render_submit()

    assert render(view) =~ "Fragebogen gespeichert"

    reloaded = Study.get_run!(run.id)
    assert reloaded.likert == %{"zufriedenheit" => 5, "freude" => 4, "fluss" => 3}
  end
end
