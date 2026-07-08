defmodule OwnershipAshChatWeb.StudyWritingLiveTest do
  use OwnershipAshChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import OwnershipAshChat.StudyGenerators

  alias OwnershipAshChat.Study

  test "renders the run and records a submitted passage", %{conn: conn} do
    run = generate(run(topic_source: :free, ai_mode: :without_ai))

    {:ok, view, html} = live(conn, ~p"/dev/study/run/#{run.id}")

    assert html =~ "Schreib-Run"
    assert html =~ "Thema wählen"

    view
    |> form("form[phx-submit=add_passage]", %{"text" => "Stille am Teich"})
    |> render_submit()

    assert render(view) =~ "Stille am Teich"

    reloaded = Study.get_run!(run.id)
    assert [%{"role" => "user", "text" => "Stille am Teich"}] = reloaded.transcript
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
