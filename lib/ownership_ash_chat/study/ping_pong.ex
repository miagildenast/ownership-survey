defmodule OwnershipAshChat.Study.PingPong do
  @moduledoc """
  Ping-pong (`:with_ai`) writing helper for study runs.

  Generates the AI's next passage from a run's current transcript by reusing the
  central LLM config (`OwnershipAshChat.LLM`) and `ReqLLM`. The chat's
  `Chat.Message.Changes.Respond` persistence is intentionally NOT reused — the
  study stores the transcript embedded on the run, not as `Chat.Message` rows.

  The responder is injectable via application config so tests can stub it and avoid
  hitting a live model:

      config :ownership_ash_chat, :study_responder, {MyStub, :reply}

  Each transcript entry is a plain map `%{"role" => "user" | "ai", "text" => ...}`
  (string keys, matching what the jsonb column returns on read).
  """

  alias OwnershipAshChat.LLM
  alias ReqLLM.Context

  @system """
  Du schreibst gemeinsam mit einer Person ein Haiku – abwechselnd, Zeile für Zeile (Ping-Pong).
  Knüpfe an das bisher Geschriebene an und antworte mit genau einer kurzen Passage
  (in der Regel eine Haiku-Zeile). Gib nur die Passage zurück, ohne Erklärungen oder Anführungszeichen.
  """

  @doc "Number of ping-pong rounds (one user + one AI passage each) per run."
  def rounds, do: Application.get_env(:ownership_ash_chat, :ping_pong_rounds, 3)

  @doc """
  Resolve and invoke the configured responder. Defaults to `generate_passage/2`.
  """
  def respond(run, opts \\ []) do
    {mod, fun} =
      Application.get_env(
        :ownership_ash_chat,
        :study_responder,
        {__MODULE__, :generate_passage}
      )

    apply(mod, fun, [run, opts])
  end

  @doc "Generate the AI's next passage from the run's transcript via the LLM."
  def generate_passage(run, _opts) do
    context =
      Context.new([Context.system(@system) | turns(run.transcript || [])])

    case ReqLLM.generate_text(ReqLLM.model!(LLM.model()), context, LLM.req_llm_opts()) do
      {:ok, response} -> response |> ReqLLM.Response.text() |> to_string() |> String.trim()
      {:error, _reason} -> "…"
    end
  end

  defp turns(transcript) do
    Enum.map(transcript, fn passage ->
      case role(passage) do
        "ai" -> Context.assistant(text(passage))
        _ -> Context.user(text(passage))
      end
    end)
  end

  defp role(%{"role" => role}), do: role
  defp role(%{role: role}), do: to_string(role)
  defp role(_), do: "user"

  defp text(%{"text" => text}), do: to_string(text)
  defp text(%{text: text}), do: to_string(text)
  defp text(_), do: ""
end
