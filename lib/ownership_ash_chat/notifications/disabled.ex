defmodule OwnershipAshChat.Notifications.Disabled do
  @moduledoc """
  No-op notifications backend — the default when `NOTIFICATION_PROVIDER` is unset (or
  unrecognized). Keeps dev/test quiet and lets prod ship without notifications until a
  provider is configured.
  """
  @behaviour OwnershipAshChat.Notifications

  @impl true
  def deliver(_message), do: :ok
end
