defmodule OwnershipAshChat.Study.Run.Changes.AddPassage do
  @moduledoc """
  Appends a user passage to a run's `transcript` and, for `:with_ai` runs that are
  still within the round limit, generates and appends the AI's reply (ping-pong).

  Non-atomic: it reads the current `transcript` and (for `:with_ai`) calls the LLM,
  so the owning action must set `require_atomic? false`.
  """
  use Ash.Resource.Change

  alias OwnershipAshChat.Study.PingPong

  @impl true
  def change(changeset, _opts, _context) do
    text = Ash.Changeset.get_argument(changeset, :text)
    run = changeset.data
    transcript = run.transcript || []

    with_user = transcript ++ [passage("user", text)]

    new_transcript =
      if run.ai_mode == :with_ai and user_count(transcript) < PingPong.rounds() do
        ai_text = PingPong.respond(%{run | transcript: with_user})
        with_user ++ [passage("ai", ai_text)]
      else
        with_user
      end

    Ash.Changeset.change_attribute(changeset, :transcript, new_transcript)
  end

  defp passage(role, text) do
    %{"role" => role, "text" => to_string(text), "at" => DateTime.utc_now()}
  end

  defp user_count(transcript) do
    Enum.count(transcript, fn
      %{"role" => "user"} -> true
      %{role: :user} -> true
      _ -> false
    end)
  end
end
