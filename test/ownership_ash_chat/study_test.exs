defmodule OwnershipAshChat.StudyTest do
  use OwnershipAshChat.DataCase, async: true

  import OwnershipAshChat.StudyGenerators

  alias OwnershipAshChat.Study

  describe "create_session/1" do
    test "creates a session with defaults" do
      session =
        Study.create_session!(%{
          case_id: "case-1",
          topic_source_order: [:free, :assigned]
        })

      assert session.case_id == "case-1"
      assert session.topic_source_order == [:free, :assigned]
      assert session.status == :in_progress
      assert session.metadata == %{}
      assert is_binary(session.id)
    end

    test "rejects an unknown topic_source value" do
      assert {:error, _} = Study.create_session(%{topic_source_order: [:nonsense]})
    end
  end

  describe "start_session/1" do
    test "creates an in_progress session for a case_id" do
      case_id = "case-#{System.unique_integer([:positive])}"
      session = Study.start_session!(%{case_id: case_id})

      assert session.case_id == case_id
      assert session.status == :in_progress
    end

    test "resumes the same session on re-entry with the same case_id" do
      case_id = "case-#{System.unique_integer([:positive])}"
      first = Study.start_session!(%{case_id: case_id})
      second = Study.start_session!(%{case_id: case_id})

      assert first.id == second.id
    end

    test "rejects a blank case_id" do
      assert {:error, _} = Study.start_session(%{case_id: ""})
    end
  end

  describe "create_run/1" do
    setup do
      %{session: generate(session())}
    end

    test "creates a writing run related to the session", %{session: session} do
      run =
        Study.create_run!(%{
          run_index: 1,
          kind: :writing,
          topic_source: :free,
          ai_mode: :with_ai,
          session_id: session.id
        })

      assert run.kind == :writing
      assert run.ai_mode == :with_ai
      assert run.transcript == []
      assert run.likert == %{}
      assert run.session_id == session.id
    end

    test "defaults kind to :writing", %{session: session} do
      run = Study.create_run!(%{run_index: 1, session_id: session.id})
      assert run.kind == :writing
    end

    test "stores modification-run fields", %{session: session} do
      run =
        Study.create_run!(%{
          kind: :modification,
          variant: :a,
          source_run_index: 2,
          original_haiku: "old",
          modified_haiku: "new",
          session_id: session.id
        })

      assert run.kind == :modification
      assert run.variant == :a
      assert run.source_run_index == 2
    end

    test "requires a session" do
      assert {:error, _} = Study.create_run(%{run_index: 1})
    end
  end

  describe "get_session/2" do
    test "loads the runs relationship" do
      session = generate(session())
      generate(run(session_id: session.id, run_index: 1))

      loaded = Study.get_session!(session.id, load: [:runs])
      assert [run] = loaded.runs
      assert run.run_index == 1
    end
  end

  describe "set_run_topic/2" do
    test "sets the topic and stamps started_at" do
      run = generate(run(topic_source: :free))
      assert is_nil(run.started_at)

      updated = Study.set_run_topic!(run, %{topic: "Herbst"})

      assert updated.topic == "Herbst"
      refute is_nil(updated.started_at)
    end
  end

  describe "add_user_passage/2" do
    test "without_ai appends only the user passage" do
      run = generate(run(ai_mode: :without_ai))

      updated = Study.add_user_passage!(run, "Stille am Teich")

      assert [%{"role" => "user", "text" => "Stille am Teich"}] = updated.transcript
    end

    test "with_ai appends the user passage and the AI reply" do
      run = generate(run(ai_mode: :with_ai))

      updated = Study.add_user_passage!(run, "Stille am Teich")

      assert [
               %{"role" => "user", "text" => "Stille am Teich"},
               %{"role" => "ai", "text" => ai_text}
             ] = updated.transcript

      assert ai_text == OwnershipAshChat.Study.PingPongStub.text()
    end

    test "with_ai run is three lines [human, AI, human], then auto-completes" do
      ai = OwnershipAshChat.Study.PingPongStub.text()

      run = generate(run(ai_mode: :with_ai))

      # Line 1 (human) triggers the AI's line 2; run not yet complete.
      run = Study.add_user_passage!(run, "Stille am Teich")
      assert [%{"role" => "user"}, %{"role" => "ai"}] = run.transcript
      assert is_nil(run.completed_at)

      # Line 3 (human) completes the run — no further AI turn.
      run = Study.add_user_passage!(run, "Frosch springt hinein")

      assert [
               %{"role" => "user", "text" => "Stille am Teich"},
               %{"role" => "ai", "text" => ^ai},
               %{"role" => "user", "text" => "Frosch springt hinein"}
             ] = run.transcript

      assert run.final_haiku == "Stille am Teich\n#{ai}\nFrosch springt hinein"
      refute is_nil(run.completed_at)
    end

    test "without_ai run is three human lines, then auto-completes" do
      run = generate(run(ai_mode: :without_ai))

      run =
        Enum.reduce(["alter Teich", "Frosch springt hinein", "Wasserklang"], run, fn line, run ->
          Study.add_user_passage!(run, line)
        end)

      assert Enum.map(run.transcript, & &1["role"]) == ["user", "user", "user"]
      assert run.final_haiku == "alter Teich\nFrosch springt hinein\nWasserklang"
      refute is_nil(run.completed_at)
    end

    test "ignores passages once the run is complete" do
      run = generate(run(ai_mode: :without_ai))

      run =
        Enum.reduce(["eins", "zwei", "drei"], run, fn line, run ->
          Study.add_user_passage!(run, line)
        end)

      after_extra = Study.add_user_passage!(run, "vier")

      assert length(after_extra.transcript) == 3
      assert after_extra.final_haiku == run.final_haiku
    end
  end

  describe "generators" do
    test "build records with unique defaults" do
      s1 = generate(session())
      s2 = generate(session())
      assert s1.case_id != s2.case_id

      run = generate(run())
      assert run.kind == :writing
      assert is_binary(run.session_id)
    end
  end
end
