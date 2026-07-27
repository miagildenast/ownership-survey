defmodule OwnershipAshChat.Study.Session.Notifiers.SessionEvents do
  @moduledoc """
  Ash notifier on the `Session` resource. Fires a notification when a session is
  marked complete (the `:complete` action). Ash runs notifiers after the transaction
  commits, so this never interferes with the write.

  Session *start* is not handled here: `:start` upserts and re-fires on every resume /
  reload, so that event is emitted from `Session.Changes.SeedRuns` (fresh-insert only).

  The message carries the session's modification variant and the split it was drawn
  against (`Balance.variant_split/1`) — the variant is only known once run 5 exists, which
  is the case by the time a session completes.
  """
  use Ash.Notifier

  alias OwnershipAshChat.Notifications.Events
  alias OwnershipAshChat.Study.Balance

  @impl true
  def notify(%Ash.Notifier.Notification{action: %{name: :complete}, data: session}) do
    case Balance.variant_split(session.id) do
      {nil, _counts} -> Events.session_completed(session)
      {variant, counts} -> Events.session_completed(session, %{variant: variant, counts: counts})
    end
  end

  def notify(_notification), do: :ok
end
