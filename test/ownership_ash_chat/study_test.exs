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

    test "with_ai stops generating AI replies past the round limit" do
      rounds = OwnershipAshChat.Study.PingPong.rounds()

      run =
        Enum.reduce(1..(rounds + 1), generate(run(ai_mode: :with_ai)), fn i, run ->
          Study.add_user_passage!(run, "Zeile #{i}")
        end)

      user_count = Enum.count(run.transcript, &(&1["role"] == "user"))
      ai_count = Enum.count(run.transcript, &(&1["role"] == "ai"))

      assert user_count == rounds + 1
      assert ai_count == rounds
    end
  end

  describe "set_final_haiku/2" do
    test "sets the final haiku and stamps completed_at" do
      run = generate(run())

      updated = Study.set_final_haiku!(run, %{final_haiku: "alter Teich\nFrosch springt hinein\nWasserklang"})

      assert updated.final_haiku =~ "Wasserklang"
      refute is_nil(updated.completed_at)
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
