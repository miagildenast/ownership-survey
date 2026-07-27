defmodule OwnershipAshChat.Notifications.DailyReport do
  @moduledoc """
  Sends the aggregate study statistics (`OwnershipAshChat.Study.Stats`) to the
  notification channel once a day **and once on app start** (so a deploy/restart
  immediately reports the current state).

  A plain `Process.send_after/3` timer — no scheduler dependency. After each run it
  recomputes the delay to the next occurrence, so a long-running node stays on time.

  ## Configuration

      config :ownership_ash_chat, :stats_report,
        enabled: true,
        at: ~T[09:30:00],
        on_start: true

  Disabled (`enabled: false`, the default) means the process is not started at all
  (`OwnershipAshChat.Application`). The time is interpreted in the **server's local
  timezone** (`NaiveDateTime.local_now/0`) — no tz database is bundled; set the host's
  timezone (Uberspace: `Europe/Berlin`) accordingly. Since the delay is recomputed from
  local time after every run, a DST switch can shift a single report by an hour; the
  next one is on time again.

  Best-effort like every other notification: a failing DB read or delivery is logged and
  swallowed, never taking the process (or the app) down.
  """
  use GenServer
  require Logger

  alias OwnershipAshChat.Notifications.Events
  alias OwnershipAshChat.Study.Stats

  @default_at ~T[09:30:00]

  def start_link(opts) do
    {gen_opts, opts} = Keyword.split(opts, [:name])
    GenServer.start_link(__MODULE__, opts, Keyword.put_new(gen_opts, :name, __MODULE__))
  end

  @doc """
  Whether the daily report is enabled (see the moduledoc for the config key).
  """
  def enabled?, do: Keyword.get(config(), :enabled, false)

  @doc "The configured local time of day the report is sent at."
  def scheduled_at, do: Keyword.get(config(), :at, @default_at)

  @doc "Whether an extra report is sent when the process starts (default `true`)."
  def on_start?, do: Keyword.get(config(), :on_start, true)

  @doc """
  Compute + deliver the report right now, regardless of the schedule. Also the body of
  the timed run; handy from IEx / `bin/ownership_ash_chat remote` to verify the wiring.
  """
  def deliver_now(event \\ :daily) do
    stats = Stats.collect!()

    case event do
      :daily -> Events.daily_stats(stats)
      :startup -> Events.startup_stats(stats)
    end
  rescue
    error ->
      Logger.warning("stats report failed: #{Exception.message(error)}")
      :error
  end

  @doc """
  Milliseconds from `now` until the next occurrence of the local time `at` — today if it
  is still ahead, otherwise tomorrow.
  """
  def next_run_in_ms(%Time{} = at, %NaiveDateTime{} = now) do
    today = NaiveDateTime.new!(NaiveDateTime.to_date(now), at)

    next =
      if NaiveDateTime.compare(today, now) == :gt,
        do: today,
        else: NaiveDateTime.add(today, 1, :day)

    NaiveDateTime.diff(next, now, :millisecond)
  end

  @impl true
  def init(opts) do
    at = Keyword.get(opts, :at, scheduled_at())
    state = schedule(%{at: at})

    if Keyword.get(opts, :on_start, on_start?()) do
      {:ok, state, {:continue, :startup_report}}
    else
      {:ok, state}
    end
  end

  # Post-init so the supervisor is not blocked by the DB read + HTTP delivery.
  @impl true
  def handle_continue(:startup_report, state) do
    deliver_now(:startup)
    {:noreply, state}
  end

  @impl true
  def handle_info(:report, state) do
    deliver_now()
    {:noreply, schedule(state)}
  end

  defp schedule(%{at: at} = state) do
    delay = next_run_in_ms(at, NaiveDateTime.local_now())
    timer = Process.send_after(self(), :report, delay)
    Map.put(state, :timer, timer)
  end

  defp config, do: Application.get_env(:ownership_ash_chat, :stats_report, [])
end
