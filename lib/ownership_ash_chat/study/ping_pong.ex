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

  require Logger

  alias OwnershipAshChat.LLM
  alias ReqLLM.Context

  @doc """
  Total number of lines (passages) a writing run holds before it auto-completes.

  A `:with_ai` run is `[human, AI, human]`, a `:without_ai` run is three human
  lines. The AI therefore takes exactly one turn — generating line 2.
  """
  def lines, do: Application.get_env(:ownership_ash_chat, :ping_pong_lines, 3)

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

  @doc """
  Generate the AI's haiku line (line 2) from the run's transcript via the LLM.

  The AI only ever takes the second turn, so the human's first line is the most
  recent passage in the transcript when this runs.
  """
  def generate_passage(run, _opts) do
    line1 = last_user_text(run.transcript || [])

    messages =
      [system_message(), Context.user(second_line_prompt(line1))]
      |> Enum.reject(&is_nil/1)

    case ReqLLM.generate_text(
           ReqLLM.model!(LLM.model()),
           Context.new(messages),
           LLM.req_llm_opts()
         ) do
      {:ok, response} ->
        response |> ReqLLM.Response.text() |> to_string() |> strip_line()

      {:error, reason} ->
        Logger.error("PingPong LLM call failed: #{inspect(reason)}")
        "error im llm"
    end
  end

  @doc """
  The literal prompt asking the model for the second haiku line, given line 1.

  TODO: this deliberately follows the study's literal prompt and does NOT pass the
  run's `topic` to the model — line 1 (written by the human to the topic) is the
  only topic signal. For `:assigned` runs the AI line could drift; injecting
  `"Thema: \#{run.topic}"` here would tie it back to the assigned topic.
  """
  def second_line_prompt(line1) do
    """
    Generate the second line of a German haiku.

    First line:
    „#{line1}“

    Constraints:
    - Output exactly one line.
    - Output language: German.
    - Do not add quotation marks.
    - Do not add explanations.
    - Do not add any text before or after the line.
    - The line must contain EXACTLY 7 syllables.
    - NEVER return a line with more or fewer than 7 syllables.
    - Return only the second line.
    """
  end

  defp system_message do
    case LLM.system_preamble() do
      preamble when is_binary(preamble) and preamble != "" -> Context.system(preamble)
      _ -> nil
    end
  end

  # Defensive: the prompt forbids quotes/extra text, but strip wrapping whitespace
  # and quote characters in case the model disobeys.
  defp strip_line(text) do
    text
    |> String.trim()
    |> String.replace(~r/^["„“”']+|["„“”']+$/u, "")
    |> String.trim()
  end

  defp last_user_text(transcript) do
    transcript
    |> Enum.reverse()
    |> Enum.find_value("", fn passage ->
      if role(passage) == "user", do: text(passage)
    end)
  end

  defp role(%{"role" => role}), do: role
  defp role(%{role: role}), do: to_string(role)
  defp role(_), do: "user"

  defp text(%{"text" => text}), do: to_string(text)
  defp text(%{text: text}), do: to_string(text)
  defp text(_), do: ""
end
