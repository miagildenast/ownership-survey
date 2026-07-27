defmodule OwnershipAshChat.Notifications.DailyReportTest do
  @moduledoc """
  Covers the daily stats report: the schedule arithmetic, the config switches, and the
  delivered message (through the forwarding test backend, see `NotificationsTest`).
  """
  use OwnershipAshChat.DataCase, async: false

  import OwnershipAshChat.StudyGenerators

  alias OwnershipAshChat.Notifications.DailyReport

  setup do
    Application.put_env(:ownership_ash_chat, :notifications_test_pid, self())
    on_exit(fn -> Application.delete_env(:ownership_ash_chat, :notifications_test_pid) end)
    :ok
  end

  describe "next_run_in_ms/2" do
    test "schedules later today when the time is still ahead" do
      now = ~N[2026-07-27 08:00:00]

      assert DailyReport.next_run_in_ms(~T[09:30:00], now) == 90 * 60 * 1000
    end

    test "schedules tomorrow when the time has passed" do
      now = ~N[2026-07-27 09:30:01]

      assert DailyReport.next_run_in_ms(~T[09:30:00], now) == (24 * 3600 - 1) * 1000
    end

    test "schedules tomorrow when it is exactly the configured time" do
      now = ~N[2026-07-27 09:30:00]

      assert DailyReport.next_run_in_ms(~T[09:30:00], now) == 24 * 3600 * 1000
    end
  end

  describe "configuration" do
    test "disabled by default in test, with 09:30 as the configured time" do
      refute DailyReport.enabled?()
      assert DailyReport.scheduled_at() == ~T[09:30:00]
    end

    test "enabled?/0 follows the :stats_report config" do
      original = Application.get_env(:ownership_ash_chat, :stats_report)

      Application.put_env(:ownership_ash_chat, :stats_report,
        enabled: true,
        at: ~T[07:15:00],
        on_start: false
      )

      on_exit(fn -> Application.put_env(:ownership_ash_chat, :stats_report, original) end)

      assert DailyReport.enabled?()
      assert DailyReport.scheduled_at() == ~T[07:15:00]
      refute DailyReport.on_start?()
    end

    test "the report on start is on by default" do
      assert DailyReport.on_start?()
    end
  end

  describe "deliver_now/1" do
    setup do
      session = generate(session(topic_source_order: [:assigned, :free]))
      generate(run(session_id: session.id, run_index: 1, ai_mode: :with_ai, likert: %{"a" => 4}))
      generate(run(session_id: session.id, run_index: 3, ai_mode: :without_ai))
      generate(run(session_id: session.id, run_index: nil, kind: :modification, variant: :b))

      :ok
    end

    test "sends one message with the current statistics" do
      DailyReport.deliver_now()

      assert_receive {:notification, message}
      assert message =~ ~S(*📊 Daily study stats — )
      # Parens are the sigil delimiter here, so use | for the lines that contain them.
      assert message =~ ~S|*Sessions:* 1 _\(0 completed, 1 in progress, 0 aborted\)_|
      assert message =~ ~S|*Duration:* median n/a _\(min n/a, max n/a, over 0 finished\)_|
      assert message =~ ~S(*Randomization*)
      assert message =~ ~S(*topic first:* assigned 1 / free 0)

      assert message =~
               ~S(*ai\_mode first:* block 1 with\_ai 1 / without\_ai 0 · block 2 with\_ai 0 / without\_ai 1)

      assert message =~ ~S(*modifications:* one word 0 / whole line 1)
      refute message =~ "Questionnaires"
    end

    test "the startup report carries the same numbers under its own heading" do
      DailyReport.deliver_now(:startup)

      assert_receive {:notification, message}
      assert message =~ ~S(*📊 Study stats at startup — )
      assert message =~ ~S(*modifications:* one word 0 / whole line 1)
    end
  end

  describe "the scheduled process" do
    test "starts, schedules a timer and stays up without delivering" do
      pid =
        start_supervised!(
          {DailyReport, at: ~T[23:59:00], on_start: false, name: :daily_report_test}
        )

      assert Process.alive?(pid)
      refute_receive {:notification, _}, 50
    end

    test "reports once on start" do
      start_supervised!({DailyReport, at: ~T[23:59:00], on_start: true, name: :daily_report_test})

      assert_receive {:notification, message}
      assert message =~ "📊 Study stats at startup"
      refute_receive {:notification, _}, 50
    end

    test "delivers and reschedules when its timer fires" do
      pid =
        start_supervised!(
          {DailyReport, at: ~T[23:59:00], on_start: false, name: :daily_report_test}
        )

      send(pid, :report)

      assert_receive {:notification, message}
      assert message =~ "📊 Daily study stats"
      assert Process.alive?(pid)
    end
  end
end
