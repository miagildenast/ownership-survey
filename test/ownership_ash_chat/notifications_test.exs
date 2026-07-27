defmodule OwnershipAshChat.NotificationsTest do
  @moduledoc """
  Covers the notification event wiring. The test backend
  (`OwnershipAshChat.Notifications.TestBackend`, configured in `config/test.exs`)
  forwards each delivered message to the pid we register below, so we can assert the
  right English text is emitted for each event.
  """
  use OwnershipAshChat.DataCase, async: false

  import OwnershipAshChat.StudyGenerators

  alias OwnershipAshChat.Notifications
  alias OwnershipAshChat.Notifications.Events
  alias OwnershipAshChat.Study

  setup do
    Application.put_env(:ownership_ash_chat, :notifications_test_pid, self())
    on_exit(fn -> Application.delete_env(:ownership_ash_chat, :notifications_test_pid) end)
    :ok
  end

  describe "Events formatting" do
    test "app lifecycle messages" do
      assert :ok = Notifications.deliver("x")

      Events.app_started()
      assert_receive {:notification, "🚀 *App started*"}

      Events.app_stopping()
      assert_receive {:notification, "🛑 *App stopping*"}
    end

    test "ai_failure includes the reason" do
      Events.ai_failure(:timeout)
      assert_receive {:notification, "⚠️ *AI generation failed:* :timeout"}
    end

    test "interpolated data is escaped for Telegram's MarkdownV2 parse mode" do
      Events.ai_failure("a_b (c). *d*")

      assert_receive {:notification, message}
      assert message == ~S|⚠️ *AI generation failed:* "a\_b \(c\)\. \*d\*"|
    end
  end

  describe "session started with a draw log" do
    @marginals %{
      topic: %{assigned: 5, free: 9},
      block_1: %{with_ai: 8, without_ai: 6},
      block_2: %{with_ai: 7, without_ai: 7}
    }

    defp draw(overrides) do
      Map.merge(
        %{
          chosen: {:assigned, :without_ai, :with_ai},
          count: 0,
          tied: 1,
          others: {1, 3},
          total: 14,
          marginals: @marginals
        },
        Map.new(overrides)
      )
    end

    test "lists the runs and explains a forced pick" do
      Events.session_started(%{case_number: "num-015"}, draw([]))

      assert_receive {:notification, message}

      assert message == """
             🟢 *Session started* — case num\\-015

             *Runs in presented order*
             1 · assigned topic · alone
             2 · assigned topic · with AI
             3 · free topic · with AI
             4 · free topic · alone

             *Why this combination*
             _· the only one of the 8 with 0 draws so far \\(others: 1–3\\)_
             _· forced, not random — no tie to break_
             _· corrects "assigned first" \\(was 5:9\\) and "block 1 without\\_ai first" \\(was 8:6\\)_\
             """
    end

    test "reports a random pick among tied cells" do
      Events.session_started(%{case_number: "num-017"}, draw(tied: 3, count: 1, others: {1, 2}))

      assert_receive {:notification, message}

      assert message =~ "_· 3 of the 8 combinations were tied at 1 draw each_"
      assert message =~ "_· picked at random among them — nothing to force_"
    end

    test "reports the very first participant" do
      zeros = %{
        topic: %{assigned: 0, free: 0},
        block_1: %{with_ai: 0, without_ai: 0},
        block_2: %{with_ai: 0, without_ai: 0}
      }

      Events.session_started(
        %{case_number: "num-001"},
        draw(total: 0, tied: 8, others: {0, 0}, marginals: zeros)
      )

      assert_receive {:notification, message}

      assert message =~ "_· first participant — all 8 combinations still at 0 draws_"
      assert message =~ "_· picked at random_"
      # Nothing lags behind yet, so there is nothing to correct.
      refute message =~ "corrects"
    end

    test "drops the corrects line when the chosen levels were not behind" do
      Events.session_started(
        %{case_number: "num-016"},
        draw(chosen: {:free, :with_ai, :with_ai})
      )

      assert_receive {:notification, message}

      # free (9 vs 5), block 1 with_ai (8 vs 6) and block 2 with_ai (7 vs 7) all lead or tie.
      refute message =~ "corrects"
    end

    test "without a draw log the message stays a single line" do
      Events.session_started(%{case_number: "num-015"})

      assert_receive {:notification, "🟢 *Session started* — case num\\-015"}
    end

    test "the whole message is valid MarkdownV2 — no unescaped reserved characters" do
      Events.session_started(%{case_number: "num-015"}, draw([]))

      assert_receive {:notification, message}

      # Strip the entity markers we emit on purpose, then nothing reserved may remain
      # unescaped (a single stray character makes Telegram reject the message).
      stripped = String.replace(message, ~r/(?<!\\)[*_]/, "")
      refute stripped =~ ~r/(?<!\\)[\[\]()~`>#+\-=|{}.!]/
    end
  end

  describe "session completed with a variant" do
    test "explains a forced variant" do
      Events.session_completed(%{case_number: "num-015"}, %{variant: :a, counts: %{a: 3, b: 11}})

      assert_receive {:notification, message}

      assert message == """
             ✅ *Session completed* — case num\\-015
             *Modification variant:* one word
             _· one word was behind 3:11 → forced_\
             """
    end

    test "explains a random pick on a tie" do
      Events.session_completed(%{case_number: "num-018"}, %{variant: :b, counts: %{a: 7, b: 7}})

      assert_receive {:notification, message}

      assert message =~ "*Modification variant:* whole line"
      assert message =~ "_· tied at 7:7 → picked at random_"
    end

    test "states the plain split for a variant that was already ahead" do
      Events.session_completed(%{case_number: "num-019"}, %{variant: :b, counts: %{a: 3, b: 11}})

      assert_receive {:notification, message}

      assert message =~ "_· split before this session was 3:11_"
    end
  end

  describe "session lifecycle wiring" do
    test "a fresh :start session announces session started with the case number" do
      case_number = "num-#{System.unique_integer([:positive])}"

      Study.start_session!(%{
        case_id: "case-#{System.unique_integer([:positive])}",
        case_number: case_number
      })

      assert_receive {:notification, message}

      # The dash in the case number is MarkdownV2-reserved, so it arrives escaped.
      assert message =~ "🟢 *Session started* — case #{Events.escape(case_number)}"

      # The drawn sequence travels with the event (SeedRuns → Events.session_started/2).
      assert message =~ "*Runs in presented order*"
      assert message =~ "*Why this combination*"
      assert message =~ "_· first participant — all 8 combinations still at 0 draws_"
    end

    test "completing a session announces session completed with the case number" do
      session = generate(session())

      Study.complete_session!(session)

      assert_receive {:notification, message}
      assert message == "✅ *Session completed* — case #{Events.escape(session.case_number)}"
    end

    test "completing a session with a modification run reports the variant" do
      session = generate(session())
      generate(run(session_id: session.id, kind: :modification, variant: :a, run_index: nil))

      Study.complete_session!(session)

      assert_receive {:notification, message}
      assert message =~ "*Modification variant:* one word"
      assert message =~ "_· tied at 0:0 → picked at random_"
    end
  end
end
