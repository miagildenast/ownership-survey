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

  def session_started(session),
    do: fire("🟢 Session started — case #{session.case_number}")

  def session_completed(session),
    do: fire("✅ Session completed — case #{session.case_number}")

  def ai_failure(reason),
    do: fire("⚠️ AI generation failed: #{inspect(reason)}")

  def app_started, do: fire("🚀 App started")

  # Synchronous on purpose — see moduledoc.
  def app_stopping, do: Notifications.deliver("🛑 App stopping")

  defp fire(message) do
    Task.start(fn -> Notifications.deliver(message) end)
    :ok
  end
end
