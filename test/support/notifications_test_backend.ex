defmodule OwnershipAshChat.Notifications.TestBackend do
  @moduledoc """
  Test backend for `OwnershipAshChat.Notifications`, wired in via config in the test
  env so notifications never hit the network. Forwards each delivered message to the
  pid registered under `:notifications_test_pid` (set to `self()` in a test), enabling
  `assert_receive {:notification, message}`. No registered pid → silent no-op.
  """
  @behaviour OwnershipAshChat.Notifications

  @impl true
  def deliver(message) do
    case Application.get_env(:ownership_ash_chat, :notifications_test_pid) do
      pid when is_pid(pid) -> send(pid, {:notification, message})
      _ -> :ok
    end

    :ok
  end
end
