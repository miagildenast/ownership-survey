defmodule OwnershipAshChat.Study do
  use Ash.Domain,
    otp_app: :ownership_ash_chat

  resources do
    resource OwnershipAshChat.Study.Session do
      define :create_session, action: :create
      define :get_session, action: :read, get_by: [:id]
    end

    resource OwnershipAshChat.Study.Run do
      define :create_run, action: :create
    end
  end
end
