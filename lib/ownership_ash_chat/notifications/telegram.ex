defmodule OwnershipAshChat.Notifications.Telegram do
  @moduledoc """
  Telegram backend for `OwnershipAshChat.Notifications`. Posts a message to a chat via
  the Telegram Bot API (`sendMessage`).

  Selected as the active backend when `NOTIFICATION_PROVIDER=TELEGRAM`; the credentials
  come from `NOTIFICATION_PROVIDER_TELEGRAM_BOT_TOKEN` / `NOTIFICATION_PROVIDER_TELEGRAM_CHAT_ID`
  (wired into `config :ownership_ash_chat, :notifications` in `config/runtime.exs`).
  Missing credentials → a silent no-op. Never raises: any transport error is logged and
  returned as `{:error, _}`.
  """
  @behaviour OwnershipAshChat.Notifications

  require Logger

  @impl true
  def deliver(message) when is_binary(message) do
    telegram =
      Application.get_env(:ownership_ash_chat, :notifications, [])
      |> Keyword.get(:telegram, [])

    token = telegram[:bot_token]
    chat_id = telegram[:chat_id]

    if is_nil(token) or is_nil(chat_id) do
      :ok
    else
      post(token, chat_id, message)
    end
  end

  defp post(token, chat_id, message) do
    url = "https://api.telegram.org/bot#{token}/sendMessage"

    case Req.post(url, json: %{chat_id: chat_id, text: message}, receive_timeout: 5_000) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        :ok

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.warning("Telegram sendMessage failed (HTTP #{status}): #{inspect(body)}")
        {:error, {:http, status}}

      {:error, reason} ->
        Logger.warning("Telegram sendMessage error: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
