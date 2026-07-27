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

  describe "session lifecycle wiring" do
    test "a fresh :start session announces session started with the case number" do
      case_number = "num-#{System.unique_integer([:positive])}"

      Study.start_session!(%{
        case_id: "case-#{System.unique_integer([:positive])}",
        case_number: case_number
      })

      # The dash in the case number is MarkdownV2-reserved, so it arrives escaped.
      escaped = Events.escape(case_number)

      assert_receive {:notification, "🟢 *Session started* — case " <> ^escaped}
    end

    test "completing a session announces session completed with the case number" do
      session = generate(session())

      Study.complete_session!(session)

      assert_receive {:notification, "✅ *Session completed* — case " <> received_case}
      assert received_case == Events.escape(session.case_number)
    end
  end
end
