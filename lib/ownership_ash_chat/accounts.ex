defmodule OwnershipAshChat.Accounts do
  use Ash.Domain,
    otp_app: :ownership_ash_chat

  resources do
    resource OwnershipAshChat.Accounts.Token
    resource OwnershipAshChat.Accounts.User
  end
end
