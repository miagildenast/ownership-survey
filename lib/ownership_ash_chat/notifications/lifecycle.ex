defmodule OwnershipAshChat.Notifications.Lifecycle do
  @moduledoc """
  App-side lifecycle notifier. Started as the last child of the supervision tree, so
  `app_started` fires only once everything else is up. Traps exits so `terminate/2`
  runs on graceful shutdown (release stop / SIGTERM) and can emit `app_stopping`.
  """
  use GenServer

  alias OwnershipAshChat.Notifications.Events

  def start_link(opts), do: GenServer.start_link(__MODULE__, :ok, opts)

  @impl true
  def init(:ok) do
    Process.flag(:trap_exit, true)
    Events.app_started()
    {:ok, %{}}
  end

  @impl true
  def terminate(_reason, _state) do
    Events.app_stopping()
    :ok
  end
end
