defmodule OwnershipAshChat.Notifications.Events do
  @moduledoc """
  High-level notification events — the API call sites should use. Each function formats
  an English message and delivers it **fire-and-forget** (`Task.start`) so a caller
  (Ash notifier, ping-pong, LiveView, application) never blocks on, nor crashes with,
  the notification backend.

  The one exception is `app_stopping/0`, which delivers synchronously: a detached task
  would be killed together with the VM before the HTTP request completes.

  ## Markup

  Messages are formatted in **Telegram's MarkdownV2**, which `Notifications.Telegram`
  sends with `parse_mode: "MarkdownV2"`. That mode reserves a long list of characters
  (`_ * [ ] ( ) ~ \\` > # + - = | { } . !`) *everywhere* in the text — an unescaped one
  makes Telegram reject the whole message with HTTP 400.

  So messages are never written as literal markup. They are assembled from `bold/1`,
  `italic/1` and `escape/1`, which escape their content first and only then wrap it in
  the entity markers. Anything interpolated (case numbers, error reasons, but equally a
  literal `ai_mode first:` with its underscore, or a date with its dashes) goes through
  them.
  """
  alias OwnershipAshChat.Notifications
  alias OwnershipAshChat.Study.Stats

  # Escaped anywhere in MarkdownV2 text, per the Bot API docs, plus the backslash itself
  # so a stray one cannot swallow the character behind it.
  @reserved ~r/[_*\[\]()~`>#+\-=|{}.!\\]/

  def session_started(session),
    do: fire("🟢 #{bold("Session started")} — case #{escape(session.case_number)}")

  def session_completed(session),
    do: fire("✅ #{bold("Session completed")} — case #{escape(session.case_number)}")

  def ai_failure(reason),
    do: fire("⚠️ #{bold("AI generation failed:")} #{escape(inspect(reason))}")

  def app_started, do: fire("🚀 #{bold("App started")}")

  @doc """
  The daily aggregate report (see `OwnershipAshChat.Notifications.DailyReport`). Takes a
  statistics map from `OwnershipAshChat.Study.Stats.compute/1`.
  """
  def daily_stats(stats), do: fire(format_stats(stats, "📊 Daily study stats"))

  @doc """
  The same aggregate report, sent once when the app boots (see
  `OwnershipAshChat.Notifications.DailyReport`) — only the heading differs.
  """
  def startup_stats(stats), do: fire(format_stats(stats, "📊 Study stats at startup"))

  @doc "The message text `daily_stats/1` sends — exposed for tests."
  def format_stats(stats, heading \\ "📊 Daily study stats") do
    %{
      sessions: sessions,
      durations: durations,
      modifications: modifications,
      randomization: %{first_topic_source: topic, first_ai_mode: ai_mode}
    } = stats

    Enum.join(
      [
        bold("#{heading} — #{Date.to_iso8601(DateTime.to_date(stats.generated_at))}"),
        "",
        stat(
          "Sessions:",
          "#{sessions.total}",
          "(#{sessions.completed} completed, #{sessions.in_progress} in progress, #{sessions.aborted} aborted)"
        ),
        stat(
          "Duration:",
          "median #{Stats.humanize_duration(durations.median_seconds)}",
          "(min #{Stats.humanize_duration(durations.min_seconds)}, max #{Stats.humanize_duration(durations.max_seconds)}, over #{durations.sessions} finished)"
        ),
        "",
        bold("Randomization"),
        stat("topic first:", "assigned #{topic.assigned} / free #{topic.free}"),
        stat(
          "ai_mode first:",
          "block 1 with_ai #{ai_mode.block_1.with_ai} / without_ai #{ai_mode.block_1.without_ai} · " <>
            "block 2 with_ai #{ai_mode.block_2.with_ai} / without_ai #{ai_mode.block_2.without_ai}"
        ),
        stat(
          "modifications:",
          "one word #{modifications.one_word} / whole line #{modifications.whole_line}"
        )
      ],
      "\n"
    )
  end

  # Synchronous on purpose — see moduledoc.
  def app_stopping, do: Notifications.deliver("🛑 #{bold("App stopping")}")

  @doc "Escape every character MarkdownV2 reserves, so `text` renders verbatim."
  def escape(text), do: text |> to_string() |> String.replace(@reserved, &("\\" <> &1))

  @doc "`text` as a MarkdownV2 bold entity, escaped."
  def bold(text), do: "*#{escape(text)}*"

  @doc "`text` as a MarkdownV2 italic entity, escaped."
  def italic(text), do: "_#{escape(text)}_"

  # One report line: bold label, plain value, optional italic note.
  defp stat(label, value), do: "#{bold(label)} #{escape(value)}"
  defp stat(label, value, note), do: "#{stat(label, value)} #{italic(note)}"

  defp fire(message) do
    Task.start(fn -> Notifications.deliver(message) end)
    :ok
  end
end
