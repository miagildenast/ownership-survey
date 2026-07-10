defmodule OwnershipAshChat.Study.ExportTest do
  use OwnershipAshChat.DataCase, async: false

  import OwnershipAshChat.StudyGenerators

  alias OwnershipAshChat.Study
  alias OwnershipAshChat.Study.Export

  defp seed_session(opts \\ []) do
    session = generate(session(opts))

    # Two writing runs (out of order) + one modification run.
    generate(run(session_id: session.id, run_index: 2, ai_mode: :without_ai))
    generate(run(session_id: session.id, run_index: 1, ai_mode: :with_ai))

    generate(
      run(
        session_id: session.id,
        run_index: nil,
        kind: :modification,
        variant: :a,
        source_run_index: 1,
        modified_line_index: 0,
        original_haiku: "old\nb\nc",
        modified_haiku: "new\nb\nc",
        transcript: [
          %{"role" => "ai_enhanced", "text" => "new"},
          %{"role" => "user", "text" => "b"},
          %{"role" => "user", "text" => "c"}
        ]
      )
    )

    session
  end

  describe "export_session/2 + serialization" do
    test "loads runs and mirrors domain attribute names" do
      session = seed_session(case_id: "case-export-1")

      map = session.id |> Study.export_session!() |> Export.session_to_map()

      assert map.session_id == session.id
      assert map.case_id == "case-export-1"
      assert map.status == :in_progress
      assert map.topic_source_order == [:free, :assigned]
      assert length(map.runs) == 3
    end

    test "export_session_by_case_id/2 loads the same session by its case_id" do
      session = seed_session(case_id: "case-export-2")

      map = "case-export-2" |> Study.export_session_by_case_id!() |> Export.session_to_map()

      assert map.session_id == session.id
      assert map.case_id == "case-export-2"
      assert length(map.runs) == 3
    end

    test "sorts writing runs by run_index with the modification run last" do
      session = seed_session()

      %{runs: runs} = session.id |> Study.export_session!() |> Export.session_to_map()

      assert Enum.map(runs, & &1.run_index) == [1, 2, nil]
      assert Enum.map(runs, & &1.kind) == [:writing, :writing, :modification]
    end

    test "writing-run map omits modification-only fields" do
      session = seed_session()

      %{runs: [writing | _]} = session.id |> Study.export_session!() |> Export.session_to_map()

      refute Map.has_key?(writing, :variant)
      refute Map.has_key?(writing, :modified_haiku)
    end

    test "modification-run map includes its variant and haiku fields" do
      session = seed_session()

      %{runs: runs} = session.id |> Study.export_session!() |> Export.session_to_map()
      modification = List.last(runs)

      assert modification.variant == :a
      assert modification.source_run_index == 1
      assert modification.modified_line_index == 0
      assert modification.original_haiku == "old\nb\nc"
      assert modification.modified_haiku == "new\nb\nc"

      # The rewritten line is tagged with the `ai_enhanced` role in the transcript.
      assert Enum.map(modification.transcript, & &1["role"]) ==
               ["ai_enhanced", "user", "user"]
    end

    test "to_json! round-trips with enums rendered as strings" do
      session = seed_session(case_id: "case-json")

      decoded = session.id |> Study.export_session!() |> Export.to_json!() |> Jason.decode!()

      assert decoded["case_id"] == "case-json"
      assert decoded["status"] == "in_progress"
      assert decoded["topic_source_order"] == ["free", "assigned"]
      assert [first | _] = decoded["runs"]
      assert first["kind"] == "writing"
    end
  end

  describe "list_sessions_for_export/2" do
    test "returns all sessions with runs loaded" do
      s1 = seed_session()
      s2 = seed_session()

      ids = Study.list_sessions_for_export!() |> Enum.map(& &1.id)

      assert s1.id in ids
      assert s2.id in ids

      json = Study.list_sessions_for_export!() |> Export.to_json!()
      assert [_ | _] = Jason.decode!(json)
    end

    test "filters by status" do
      session = seed_session()

      completed_ids =
        Study.list_sessions_for_export!(%{status: :completed}) |> Enum.map(& &1.id)

      refute session.id in completed_ids
    end
  end
end
