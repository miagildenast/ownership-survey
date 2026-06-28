defmodule OwnershipAshChat.Chat do
  use Ash.Domain, otp_app: :ownership_ash_chat, extensions: [AshAi, AshPhoenix]

  tools do
    tool :chat_list_conversations, OwnershipAshChat.Chat.Conversation, :my_conversations do
      description "List chat conversations visible to the current actor."
    end

    tool :chat_message_history, OwnershipAshChat.Chat.Message, :for_conversation do
      description "Read chat messages for a conversation_id."
    end
  end

  resources do
    resource OwnershipAshChat.Chat.Conversation do
      define :create_conversation, action: :create
      define :get_conversation, action: :read, get_by: [:id]
      define :my_conversations
    end

    resource OwnershipAshChat.Chat.Message do
      define :message_history,
        action: :for_conversation,
        args: [:conversation_id],
        default_options: [query: [sort: [inserted_at: :desc]]]

      define :create_message, action: :create
    end
  end
end
