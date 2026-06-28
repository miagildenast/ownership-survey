defmodule OwnershipAshChat.Secrets do
  use AshAuthentication.Secret

  def secret_for(
        [:authentication, :tokens, :signing_secret],
        OwnershipAshChat.Accounts.User,
        _opts,
        _context
      ) do
    Application.fetch_env(:ownership_ash_chat, :token_signing_secret)
  end
end
