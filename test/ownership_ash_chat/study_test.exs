defmodule OwnershipAshChat.StudyTest do
  use OwnershipAshChat.DataCase, async: false

  import OwnershipAshChat.StudyGenerators

  alias OwnershipAshChat.Study
  alias OwnershipAshChat.Study.Randomization

  describe "create_session/1" do
    test "creates a session with defaults" do
      session =
        Study.create_session!(%{
          case_id: "case-1",
          case_number: "num-1",
          topic_source_order: [:free, :assigned]
        })

      assert session.case_id == "case-1"
      assert session.case_number == "num-1"
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
    defp start_params do
      %{
        case_id: "case-#{System.unique_integer([:positive])}",
        case_number: "num-#{System.unique_integer([:positive])}"
      }
    end

    test "creates an in_progress session for a case_id and case_number" do
      params = start_params()
      session = Study.start_session!(params)

      assert session.case_id == params.case_id
      assert session.case_number == params.case_number
      assert session.status == :in_progress
    end

    test "resumes the same session on re-entry with the same case_id" do
      params = start_params()
      first = Study.start_session!(params)
      second = Study.start_session!(params)

      assert first.id == second.id
    end

    test "draws topic_source_order and seeds 4 writing runs" do
      session = Study.start_session!(start_params())

      assert Enum.sort(session.topic_source_order) == [:assigned, :free]
      refute is_nil(session.started_at)

      loaded = Study.get_session!(session.id, load: [:runs])
      runs = Enum.sort_by(loaded.runs, & &1.run_index)

      assert length(runs) == 4
      assert Enum.map(runs, & &1.run_index) == [1, 2, 3, 4]
      assert Enum.all?(runs, &(&1.kind == :writing))

      # Runs follow the drawn block order; both ai_modes appear in each block.
      [r1, r2, r3, r4] = runs
      assert [r1.topic_source, r3.topic_source] == session.topic_source_order
      assert r1.topic_source == r2.topic_source
      assert r3.topic_source == r4.topic_source
      assert Enum.sort([r1.ai_mode, r2.ai_mode]) == [:with_ai, :without_ai]
      assert Enum.sort([r3.ai_mode, r4.ai_mode]) == [:with_ai, :without_ai]

      # :assigned runs carry the fixed study topic; :free runs stay topic-less.
      for run <- runs do
        case run.topic_source do
          :assigned -> assert run.topic == "Jahreszeiten"
          :free -> assert is_nil(run.topic)
        end
      end
    end

    test "re-entry does not duplicate runs (idempotent seed)" do
      params = start_params()
      first = Study.start_session!(params)
      Study.start_session!(params)

      loaded = Study.get_session!(first.id, load: [:runs])
      assert length(loaded.runs) == 4
    end

    test "eight sessions cover all eight sequences exactly once" do
      sequences =
        for _ <- 1..8 do
          session = Study.start_session!(start_params())
          runs = Study.get_session!(session.id, load: [:runs]).runs
          by_index = Map.new(runs, &{&1.run_index, &1})

          {by_index[1].topic_source, by_index[1].ai_mode, by_index[3].ai_mode}
        end

      # Balanced draw: each cell is taken before any is repeated, which also makes every
      # marginal split of the stats report land at 4:4.
      assert Enum.sort(sequences) == Enum.sort(Randomization.sequences())

      assert sequences |> Enum.map(&elem(&1, 0)) |> Enum.frequencies() ==
               %{assigned: 4, free: 4}

      assert sequences |> Enum.map(&elem(&1, 1)) |> Enum.frequencies() ==
               %{with_ai: 4, without_ai: 4}

      assert sequences |> Enum.map(&elem(&1, 2)) |> Enum.frequencies() ==
               %{with_ai: 4, without_ai: 4}
    end

    test "rejects a blank case_id" do
      assert {:error, _} =
               Study.start_session(%{case_id: "", case_number: "num-x"})
    end

    test "rejects a blank case_number" do
      assert {:error, _} =
               Study.start_session(%{case_id: "case-x", case_number: ""})
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

  describe "create_modification_run/1" do
    # Fixed replacement line so the modification never hits a live LLM.
    def stub_modification(_haiku, _variant, _line_index, _opts), do: "MOD-Zeile"

    setup do
      Application.put_env(
        :ownership_ash_chat,
        :study_modification_responder,
        {__MODULE__, :stub_modification}
      )

      on_exit(fn ->
        Application.delete_env(:ownership_ash_chat, :study_modification_responder)
      end)
    end

    @likert %{likert: %{"zufriedenheit" => 5, "freude" => 4, "fluss" => 3}}

    # Complete a :without_ai writing run (three human lines + questionnaire).
    defp complete_solo_run(session, run_index) do
      run =
        generate(
          run(
            session_id: session.id,
            run_index: run_index,
            topic_source: :free,
            ai_mode: :without_ai
          )
        )

      completed =
        Enum.reduce(["eins", "zwei", "drei"], run, fn line, r ->
          Study.add_user_passage!(r, line)
        end)

      Study.submit_likert!(completed, @likert)
    end

    test "targets the participant's first line (:without_ai → line 1)" do
      session = generate(session())
      complete_solo_run(session, 1)

      mod = Study.create_modification_run!(session.id)

      assert mod.kind == :modification
      assert mod.source_run_index == 1
      assert mod.variant in [:a, :b]
      assert mod.modified_line_index == 0
      assert mod.original_haiku == "eins\nzwei\ndrei"
      # Only the first line changed; the rest are byte-identical.
      assert mod.modified_haiku == "MOD-Zeile\nzwei\ndrei"
    end

    test "tags the rewritten line with the ai_enhanced role" do
      session = generate(session())
      complete_solo_run(session, 1)

      mod = Study.create_modification_run!(session.id)

      assert Enum.map(mod.transcript, & &1["role"]) == ["ai_enhanced", "user", "user"]
      assert Enum.map(mod.transcript, & &1["text"]) == ["MOD-Zeile", "zwei", "drei"]
    end

    test "targets line 2 when the best run is :assigned/:with_ai" do
      session = generate(session())

      run =
        generate(
          run(
            session_id: session.id,
            run_index: 1,
            topic_source: :assigned,
            ai_mode: :with_ai,
            topic: "Jahreszeiten"
          )
        )

      # [AI, user, AI]: opener from begin_run, then one human line closes the run.
      begun = Study.begin_run!(run)
      completed = Study.add_user_passage!(begun, "meine Zeile")
      Study.submit_likert!(completed, @likert)

      mod = Study.create_modification_run!(session.id)

      assert mod.modified_line_index == 1
      assert Enum.at(mod.transcript, 1)["role"] == "ai_enhanced"
      # The AI-written outer lines are preserved unchanged.
      assert Enum.at(mod.transcript, 0)["role"] == "ai"
      assert Enum.at(mod.transcript, 2)["role"] == "ai"
    end

    test "balances the variant across sessions instead of flipping a coin" do
      variants =
        for _ <- 1..4 do
          session = generate(session())
          complete_solo_run(session, 1)

          Study.create_modification_run!(session.id).variant
        end

      # Four draws against the running split → an exact 2:2, whatever the first pick was.
      assert Enum.frequencies(variants) == %{a: 2, b: 2}
    end

    test "picks the writing run with the highest Likert average" do
      session = generate(session())

      low = complete_solo_run(session, 1)
      Study.submit_likert!(low, %{likert: %{"zufriedenheit" => 1, "freude" => 1, "fluss" => 1}})
      complete_solo_run(session, 2)

      mod = Study.create_modification_run!(session.id)

      assert mod.source_run_index == 2
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

  describe "begin_run/1" do
    test "stamps started_at" do
      run = generate(run(topic_source: :free, ai_mode: :without_ai))
      assert is_nil(run.started_at)

      updated = Study.begin_run!(run)

      refute is_nil(updated.started_at)
      assert updated.transcript == []
    end

    test "assigned/with_ai opens with the AI's first line" do
      run = generate(run(topic_source: :assigned, ai_mode: :with_ai, topic: "Jahreszeiten"))

      updated = Study.begin_run!(run)

      assert [%{"role" => "ai", "text" => ai_text}] = updated.transcript
      assert ai_text == OwnershipAshChat.Study.PingPongStub.text()
      refute is_nil(updated.started_at)
    end

    test "is idempotent: re-invoking does not add another opener or move started_at" do
      run = generate(run(topic_source: :assigned, ai_mode: :with_ai, topic: "Jahreszeiten"))

      begun = Study.begin_run!(run)
      again = Study.begin_run!(begun)

      assert length(again.transcript) == 1
      assert again.started_at == begun.started_at
    end

    test "free/with_ai gets no opener — the participant writes first" do
      run = generate(run(topic_source: :free, ai_mode: :with_ai))

      updated = Study.begin_run!(run)

      assert updated.transcript == []
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

    test "with_ai persists fallback candidates when the AI could not hit the syllable target" do
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

      updated = Study.add_user_passage!(run, "Stille am Teich")

      assert [%{"role" => "user"}, ai_passage] = updated.transcript
      assert ai_passage["role"] == "ai"
      assert ai_passage["text"] == "Kurze Zeile"
      assert ai_passage["fallback"] == true
      assert ai_passage["candidates"] == ["Kurze Zeile", "Andere Zeile"]
    end

    test "free/with_ai run is three lines [human, AI, human], then auto-completes" do
      ai = OwnershipAshChat.Study.PingPongStub.text()

      run = generate(run(topic_source: :free, ai_mode: :with_ai))

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

    test "assigned/with_ai run is [AI, human, AI]: one human line completes it" do
      ai = OwnershipAshChat.Study.PingPongStub.text()

      run =
        generate(run(topic_source: :assigned, ai_mode: :with_ai, topic: "Jahreszeiten"))
        |> Study.begin_run!()

      run = Study.add_user_passage!(run, "Frosch springt hinein")

      assert [
               %{"role" => "ai", "text" => ^ai},
               %{"role" => "user", "text" => "Frosch springt hinein"},
               %{"role" => "ai", "text" => ^ai}
             ] = run.transcript

      assert run.final_haiku == "#{ai}\nFrosch springt hinein\n#{ai}"
      refute is_nil(run.completed_at)
    end

    test "assigned/with_ai fills a missing opener defensively on the first user passage" do
      ai = OwnershipAshChat.Study.PingPongStub.text()

      # No begin_run — the opener is missing when the user submits.
      run = generate(run(topic_source: :assigned, ai_mode: :with_ai, topic: "Jahreszeiten"))

      run = Study.add_user_passage!(run, "Frosch springt hinein")

      assert Enum.map(run.transcript, & &1["role"]) == ["ai", "user", "ai"]
      assert run.final_haiku == "#{ai}\nFrosch springt hinein\n#{ai}"
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

  describe "submit_likert/2" do
    test "stores a complete, valid answer map" do
      run = generate(run())

      updated =
        Study.submit_likert!(run, %{likert: %{"zufriedenheit" => 5, "freude" => 4, "fluss" => 3}})

      assert updated.likert == %{"zufriedenheit" => 5, "freude" => 4, "fluss" => 3}
    end

    test "rejects an incomplete answer map" do
      run = generate(run())

      assert {:error, _} = Study.submit_likert(run, %{likert: %{"zufriedenheit" => 5}})
    end

    test "rejects a value outside the scale" do
      run = generate(run())

      assert {:error, _} =
               Study.submit_likert(run, %{
                 likert: %{"zufriedenheit" => 6, "freude" => 4, "fluss" => 3}
               })
    end

    test "rejects an unknown item key" do
      run = generate(run())

      assert {:error, _} =
               Study.submit_likert(run, %{
                 likert: %{"zufriedenheit" => 5, "freude" => 4, "fluss" => 3, "extra" => 2}
               })
    end
  end

  describe "submit_likert/2 open-ended answers" do
    @likert %{"zufriedenheit" => 5, "freude" => 4, "fluss" => 3}

    test "a writing run must not carry open answers" do
      run = generate(run())

      assert {:error, _} =
               Study.submit_likert(run, %{likert: @likert, open_answers: %{"begruendung" => "x"}})
    end

    test "a modification run rejects unknown open-answer keys" do
      run = generate(run(kind: :modification, run_index: nil))

      assert {:error, _} =
               Study.submit_likert(run, %{
                 likert: @likert,
                 open_answers: %{"begruendung" => "ok", "nicht_konfiguriert" => "x"}
               })
    end

    test "a modification run rejects non-string open-answer values" do
      run = generate(run(kind: :modification, run_index: nil))

      assert {:error, _} =
               Study.submit_likert(run, %{likert: @likert, open_answers: %{"begruendung" => 5}})
    end

    test "a modification run accepts and persists complete open answers" do
      run = generate(run(kind: :modification, run_index: nil))
      answers = %{"begruendung" => "Klingt runder.", "anmerkungen" => "Keine."}

      updated = Study.submit_likert!(run, %{likert: @likert, open_answers: answers})

      assert updated.open_answers == answers
    end

    test "a modification run accepts a blank open answer (matches non-required textarea)" do
      run = generate(run(kind: :modification, run_index: nil))

      # Missing entirely — as when the participant submits an empty textarea.
      assert %{kind: :modification} = Study.submit_likert!(run, %{likert: @likert})

      # Explicitly blank value on one key.
      run2 = generate(run(kind: :modification, run_index: nil))

      assert %{kind: :modification} =
               Study.submit_likert!(run2, %{
                 likert: @likert,
                 open_answers: %{"begruendung" => "  ", "anmerkungen" => "ok"}
               })
    end

    test "export includes open_answers only for the modification run" do
      writing = generate(run())
      modification = generate(run(kind: :modification, run_index: nil))

      refute Map.has_key?(Study.Export.run_to_map(writing), :open_answers)
      assert Map.has_key?(Study.Export.run_to_map(modification), :open_answers)
    end
  end

  describe "complete_session/1" do
    test "marks session :completed and stamps completed_at" do
      session = generate(session())

      assert session.status == :in_progress
      assert is_nil(session.completed_at)

      completed = Study.complete_session!(session)

      assert completed.status == :completed
      refute is_nil(completed.completed_at)
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
