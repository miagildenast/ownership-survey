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
  alias OwnershipAshChat.Study.Randomization
  alias OwnershipAshChat.Study.Stats

  # Escaped anywhere in MarkdownV2 text, per the Bot API docs, plus the backslash itself
  # so a stray one cannot swallow the character behind it.
  @reserved ~r/[_*\[\]()~`>#+\-=|{}.!\\]/

  # Participant-facing wording for the run list — the raw atoms (`with_ai`, `assigned`)
  # only show up in the reason block, spelled like in the stats report so both can be read
  # against each other.
  @topic_labels %{assigned: "assigned topic", free: "free topic"}
  @ai_labels %{with_ai: "with AI", without_ai: "alone"}
  @variant_labels %{a: "one word", b: "whole line"}

  # Report order for the marginal splits quoted in the reason block.
  @topic_sources [:assigned, :free]
  @ai_modes [:with_ai, :without_ai]

  @doc """
  A new participant started. With a draw log from `Study.Randomization` (via
  `Session.Changes.SeedRuns`) the message also lists the four runs in presented order and
  explains why that combination was drawn; without one it stays a single line.
  """
  def session_started(session, draw \\ nil)

  def session_started(session, nil), do: fire(session_started_heading(session))

  def session_started(session, draw) do
    [session_started_heading(session), "", bold("Runs in presented order")]
    |> Enum.concat(sequence_lines(draw.chosen))
    |> Enum.concat(["", bold("Why this combination")])
    |> Enum.concat(reason_bullets(draw))
    |> Enum.join("\n")
    |> fire()
  end

  @doc """
  A participant finished. With `%{variant: …, counts: …}` (the split *before* this
  session's own draw, from `Study.Balance.variant_split/1`) the message also names the
  modification variant and why it was picked.
  """
  def session_completed(session, variant_info \\ nil)

  def session_completed(session, nil), do: fire(session_completed_heading(session))

  def session_completed(session, %{variant: variant, counts: counts}) do
    [
      session_completed_heading(session),
      "#{bold("Modification variant:")} #{escape(@variant_labels[variant])}",
      variant_bullet(variant, counts)
    ]
    |> Enum.join("\n")
    |> fire()
  end

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

  defp session_started_heading(session),
    do: "🟢 #{bold("Session started")} — case #{escape(session.case_number)}"

  defp session_completed_heading(session),
    do: "✅ #{bold("Session completed")} — case #{escape(session.case_number)}"

  # The four runs of the drawn sequence, in presented order.
  defp sequence_lines(sequence) do
    sequence
    |> Randomization.expand_sequence()
    |> Enum.with_index(1)
    |> Enum.map(fn {{topic_source, ai_mode}, run_index} ->
      escape("#{run_index} · #{@topic_labels[topic_source]} · #{@ai_labels[ai_mode]}")
    end)
  end

  # Why this sequence: how rare it was, whether it was forced, and which lagging split it
  # pulls back (that last bullet only when it actually applies).
  defp reason_bullets(draw) do
    [cell_bullet(draw), pick_bullet(draw)] ++ correction_bullets(draw)
  end

  defp cell_bullet(%{total: 0}),
    do: bullet("first participant — all 8 combinations still at 0 draws")

  defp cell_bullet(%{tied: 1, count: count, others: {minimum, maximum}}),
    do:
      bullet("the only one of the 8 with #{draws(count)} so far (others: #{minimum}–#{maximum})")

  defp cell_bullet(%{tied: tied, count: count}),
    do: bullet("#{tied} of the 8 combinations were tied at #{draws(count)} each")

  defp pick_bullet(%{total: 0}), do: bullet("picked at random")
  defp pick_bullet(%{tied: 1}), do: bullet("forced, not random — no tie to break")
  defp pick_bullet(_draw), do: bullet("picked at random among them — nothing to force")

  defp correction_bullets(%{chosen: {topic_source, block_1, block_2}, marginals: marginals}) do
    corrections =
      [
        correction(marginals.topic, topic_source, @topic_sources, "#{topic_source} first"),
        correction(marginals.block_1, block_1, @ai_modes, "block 1 #{block_1} first"),
        correction(marginals.block_2, block_2, @ai_modes, "block 2 #{block_2} first")
      ]
      |> Enum.reject(&is_nil/1)

    case corrections do
      [] -> []
      corrections -> [bullet("corrects " <> Enum.join(corrections, " and "))]
    end
  end

  defp correction_bullets(_draw), do: []

  # A split is only "corrected" when the chosen level was the one lagging behind. Counts
  # are quoted in report order (assigned:free, with_ai:without_ai).
  defp correction(counts, chosen, [first, second], label) do
    behind = if chosen == first, do: second, else: first

    if counts[chosen] < counts[behind] do
      ~s|"#{label}" (was #{counts[first]}:#{counts[second]})|
    end
  end

  # Why this modification variant, given the split before it was assigned.
  defp variant_bullet(variant, counts) do
    split = "#{counts.a}:#{counts.b}"
    label = @variant_labels[variant]
    other = if variant == :a, do: :b, else: :a

    cond do
      counts[variant] < counts[other] -> bullet("#{label} was behind #{split} → forced")
      counts[variant] == counts[other] -> bullet("tied at #{split} → picked at random")
      true -> bullet("split before this session was #{split}")
    end
  end

  defp bullet(text), do: italic("· " <> text)

  defp draws(1), do: "1 draw"
  defp draws(count), do: "#{count} draws"

  defp fire(message) do
    Task.start(fn -> Notifications.deliver(message) end)
    :ok
  end
end
