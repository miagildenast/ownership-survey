defmodule OwnershipAshChat.Notifications do
  @moduledoc """
  Pluggable notification facade. Delegates `deliver/1` to a swappable backend via
  `Knigge`; the default (and, for now, only) backend is `Notifications.Telegram`.

  The backend is selected at runtime from `config/runtime.exs` via the
  `NOTIFICATION_PROVIDER` env var (`TELEGRAM` → `Notifications.Telegram`; unset/other →
  `Notifications.Disabled`, a silent no-op). Runtime delegation (`delegate_at_runtime?`)
  is required so the env-var choice — applied after compile, before boot — actually wins
  in a release.

  Call sites should use `OwnershipAshChat.Notifications.Events`, which formats the
  message and delivers it fire-and-forget, rather than calling `deliver/1` directly.
  """
  use Knigge,
    otp_app: :ownership_ash_chat,
    default: OwnershipAshChat.Notifications.Disabled,
    delegate_at_runtime?: true

  @callback deliver(message :: String.t()) :: :ok | {:error, term()}
end
