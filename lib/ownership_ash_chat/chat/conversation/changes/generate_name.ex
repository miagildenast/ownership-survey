defmodule OwnershipAshChat.Chat.Conversation.Changes.GenerateName do
  use Ash.Resource.Change
  require Ash.Query

  alias ReqLLM.Context

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.before_transaction(changeset, fn changeset ->
      conversation = changeset.data

      messages =
        OwnershipAshChat.Chat.Message
        |> Ash.Query.filter(conversation_id == ^conversation.id)
        |> Ash.Query.limit(10)
        |> Ash.Query.select([:text, :source])
        |> Ash.Query.sort(inserted_at: :asc)
        |> Ash.read!(scope: context)

      prompt_messages =
        [
          Context.system("""
          Provide a short name for the current conversation.
          2-8 words, preferring more succinct names.
          RESPOND WITH ONLY THE NEW CONVERSATION NAME.
          """)
        ] ++
          Enum.map(messages, fn message ->
            if message.source == :agent do
              Context.assistant(message.text)
            else
              Context.user(message.text)
            end
          end)

      ReqLLM.generate_text(
        OwnershipAshChat.LLM.model(),
        prompt_messages,
        OwnershipAshChat.LLM.req_llm_opts()
      )
      |> case do
        {:ok, response} ->
          Ash.Changeset.force_change_attribute(
            changeset,
            :title,
            ReqLLM.Response.text(response)
          )

        {:error, error} ->
          {:error, error}
      end
    end)
  end
end
