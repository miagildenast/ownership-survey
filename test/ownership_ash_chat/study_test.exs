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
