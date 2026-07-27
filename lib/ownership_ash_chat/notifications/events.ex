defmodule OwnershipAshChat.Notifications.Events do
  @moduledoc """
  High-level notification events — the API call sites should use. Each function formats
  an English message and delivers it **fire-and-forget** (`Task.start`) so a caller
  (Ash notifier, ping-pong, LiveView, application) never blocks on, nor crashes with,
  the notification backend.

  The one exception is `app_stopping/0`, which delivers synchronously: a detached task
  would be killed together with the VM before the HTTP request completes.
  """
  alias OwnershipAshChat.Notifications
  alias OwnershipAshChat.Study.Stats

  def session_started(session),
    do: fire("🟢 Session started — case #{session.case_number}")

  def session_completed(session),
    do: fire("✅ Session completed — case #{session.case_number}")

  def ai_failure(reason),
    do: fire("⚠️ AI generation failed: #{inspect(reason)}")

  def app_started, do: fire("🚀 App started")

  @doc """
  The daily aggregate report (see `OwnershipAshChat.Notifications.DailyReport`). Takes a
  statistics map from `OwnershipAshChat.Study.Stats.compute/1`.
  """
  def daily_stats(stats), do: fire(format_stats(stats))

  @doc "The message text `daily_stats/1` sends — exposed for tests."
  def format_stats(stats) do
    %{
      sessions: sessions,
      surveys: surveys,
      durations: durations,
      randomization: %{first_topic_source: topic, first_ai_mode: ai_mode}
    } = stats

    """
    📊 Daily study stats — #{Date.to_iso8601(DateTime.to_date(stats.generated_at))}
    Sessions: #{sessions.total} (#{sessions.completed} completed, #{sessions.in_progress} in progress, #{sessions.aborted} aborted)
    Questionnaires submitted: #{surveys.submitted} (#{surveys.writing} writing, #{surveys.modification} modification)
    Duration of #{durations.sessions} finished sessions: median #{Stats.humanize_duration(durations.median_seconds)} (min #{Stats.humanize_duration(durations.min_seconds)}, max #{Stats.humanize_duration(durations.max_seconds)})
    Randomization — topic first: assigned #{topic.assigned} / free #{topic.free}
    Randomization — ai_mode first: block 1 with_ai #{ai_mode.block_1.with_ai} / without_ai #{ai_mode.block_1.without_ai} · block 2 with_ai #{ai_mode.block_2.with_ai} / without_ai #{ai_mode.block_2.without_ai}\
    """
  end

  # Synchronous on purpose — see moduledoc.
  def app_stopping, do: Notifications.deliver("🛑 App stopping")

  defp fire(message) do
    Task.start(fn -> Notifications.deliver(message) end)
    :ok
  end
end
