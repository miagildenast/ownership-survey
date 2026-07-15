defmodule OwnershipAshChat.Study.Session.Notifiers.SessionEvents do
  @moduledoc """
  Ash notifier on the `Session` resource. Fires a notification when a session is
  marked complete (the `:complete` action). Ash runs notifiers after the transaction
  commits, so this never interferes with the write.

  Session *start* is not handled here: `:start` upserts and re-fires on every resume /
  reload, so that event is emitted from `Session.Changes.SeedRuns` (fresh-insert only).
  """
  use Ash.Notifier

  alias OwnershipAshChat.Notifications.Events

  @impl true
  def notify(%Ash.Notifier.Notification{action: %{name: :complete}, data: session}) do
    Events.session_completed(session)
  end

  def notify(_notification), do: :ok
end
