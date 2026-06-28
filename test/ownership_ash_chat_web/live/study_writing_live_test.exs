defmodule OwnershipAshChatWeb.StudyWritingLiveTest do
  use OwnershipAshChatWeb.ConnCase, async: true

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

  test "submitting the final haiku completes the run", %{conn: conn} do
    run = generate(run(ai_mode: :without_ai))

    {:ok, view, _html} = live(conn, ~p"/dev/study/run/#{run.id}")

    view
    |> form("form[phx-submit=set_final_haiku]", %{"final_haiku" => "alter Teich"})
    |> render_submit()

    reloaded = Study.get_run!(run.id)
    assert reloaded.final_haiku == "alter Teich"
    refute is_nil(reloaded.completed_at)
  end
end
