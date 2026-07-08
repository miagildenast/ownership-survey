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
  alias OwnershipAshChat.Study.Syllables
  alias ReqLLM.Context

  @target_syllables 7

  @doc """
  Total number of lines (passages) a writing run holds before it auto-completes.

  A `:with_ai` run is `[human, AI, human]`, a `:without_ai` run is three human
  lines. The AI therefore takes exactly one turn — generating line 2.
  """
  def lines, do: Application.get_env(:ownership_ash_chat, :ping_pong_lines, 3)

  @doc """
  Max number of LLM attempts to produce a valid (7-syllable) second line before
  giving up and returning the closest candidate. Tunable via app env.
  """
  def line_attempts, do: Application.get_env(:ownership_ash_chat, :ping_pong_line_attempts, 4)

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
  Generate the AI's haiku line (line 2) from the run's transcript.

  The AI only ever takes the second turn, so the human's first line is the most
  recent passage in the transcript when this runs. Each generated line is validated
  against the target syllable count (`Syllables.count/1`); on a mismatch the model is
  re-prompted with corrective feedback, up to `line_attempts/0` times.

  Returns:

    * `{:ok, line}` — a valid 7-syllable line was produced.
    * `{:fallback, line, candidates}` — no attempt hit the target; `line` is the
      candidate closest to 7 syllables and `candidates` lists every tried line, in
      order. Callers surface this so the participant knows the line is unreliable.

  Text generation is injectable (per prompt) via `opts[:line_generator]` or the
  `:study_line_generator` app env, mirroring the `:study_responder` pattern so tests
  can drive the loop without a live model.
  """
  def generate_passage(run, opts \\ []) do
    line1 = last_user_text(run.transcript || [])
    generator = line_generator(opts)
    attempt_line(line1, generator, line_attempts(opts), nil, [])
  end

  defp attempt_line(line1, generator, remaining, previous, candidates) do
    prompt =
      case previous do
        nil -> second_line_prompt(line1)
        {bad_line, count} -> second_line_retry_prompt(line1, bad_line, count)
      end

    line = generator |> invoke_generator(prompt) |> strip_line()
    count = Syllables.count(line)
    candidates = candidates ++ [line]

    cond do
      count == @target_syllables ->
        {:ok, line}

      remaining <= 1 ->
        Logger.warning(
          "PingPong: no valid 7-syllable line for #{inspect(line1)} after " <>
            "#{length(candidates)} attempts; using closest candidate #{inspect(closest_candidate(candidates))}. " <>
            "Tried: #{inspect(candidates)}"
        )

        {:fallback, closest_candidate(candidates), candidates}

      true ->
        Logger.debug(
          "PingPong retry: line #{inspect(line)} has #{count} syllables (target 7); " <>
            "re-prompting, #{remaining - 1} attempt(s) left"
        )

        attempt_line(line1, generator, remaining - 1, {line, count}, candidates)
    end
  end

  defp closest_candidate(candidates) do
    Enum.min_by(candidates, fn line -> abs(Syllables.count(line) - @target_syllables) end)
  end

  defp line_generator(opts) do
    opts[:line_generator] ||
      Application.get_env(
        :ownership_ash_chat,
        :study_line_generator,
        {__MODULE__, :complete_line}
      )
  end

  defp line_attempts(opts), do: opts[:line_attempts] || line_attempts()

  defp invoke_generator(fun, prompt) when is_function(fun, 1), do: fun.(prompt)
  defp invoke_generator({mod, fun}, prompt), do: apply(mod, fun, [prompt])

  @doc """
  Default line generator: send a single prompt to the LLM and return its raw text.

  Returns a sentinel string on hard LLM error (unchanged from the prior behavior);
  the retry loop treats it as just another candidate.
  """
  def complete_line(prompt) do
    messages =
      [system_message(), Context.user(prompt)]
      |> Enum.reject(&is_nil/1)

    case ReqLLM.generate_text(
           ReqLLM.model!(LLM.model()),
           Context.new(messages),
           LLM.req_llm_opts()
         ) do
      {:ok, response} ->
        response |> ReqLLM.Response.text() |> to_string()

      {:error, reason} ->
        Logger.error("PingPong LLM call failed: #{inspect(reason)}")
        "error im llm"
    end
  end

  @doc """
  Resolve and invoke the configured modification responder. Defaults to
  `generate_modification/3`. Injectable via:

      config :ownership_ash_chat, :study_modification_responder, {MyStub, :reply}
  """
  def respond_modification(haiku, variant, opts \\ []) do
    {mod, fun} =
      Application.get_env(
        :ownership_ash_chat,
        :study_modification_responder,
        {__MODULE__, :generate_modification}
      )

    apply(mod, fun, [haiku, variant, opts])
  end

  # FIXME: no syllable validation/retry here — the modified haiku can drift from 5-7-5.
  # Apply the same validate-and-reprompt loop used for the second line
  # (`attempt_line/5` + `Syllables.count/1`), checking each of the 3 lines and
  # surfacing a fallback when the model won't converge.
  @doc """
  Call the LLM to produce a variant-modified copy of a German haiku.

  Falls back to the original haiku unchanged on LLM error.
  """
  def generate_modification(haiku, variant, _opts \\ []) do
    messages =
      [system_message(), Context.user(modification_prompt(haiku, variant))]
      |> Enum.reject(&is_nil/1)

    case ReqLLM.generate_text(
           ReqLLM.model!(LLM.model()),
           Context.new(messages),
           LLM.req_llm_opts()
         ) do
      {:ok, response} ->
        response |> ReqLLM.Response.text() |> to_string() |> strip_haiku()

      {:error, reason} ->
        Logger.error("PingPong modification LLM call failed: #{inspect(reason)}")
        haiku
    end
  end

  @doc """
  Prompt asking the model to modify a haiku according to the given variant.

  Variant `:a` = one word changed, `:b` = one line replaced, `:c` = two lines replaced.
  """
  def modification_prompt(haiku, variant) do
    change_desc =
      case variant do
        :a -> "Change exactly one word in the entire haiku."
        :b -> "Replace exactly one complete line of the haiku."
        :c -> "Replace exactly two complete lines of the haiku."
      end

    """
    Modify the following German haiku.

    Original haiku:
    #{haiku}

    Modification: #{change_desc}

    Constraints:
    - Keep exactly 3 lines.
    - Output language: German.
    - Do not add quotation marks, explanations, or any additional text.
    - Output only the modified haiku (3 lines).
    """
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
    - Before answering, split every word into syllables and count them.
    - Return only the second line.
    """
  end

  @doc """
  Corrective prompt used after a rejected attempt: it names the rejected line and its
  measured syllable count so the model gets concrete feedback instead of re-rolling
  blind.
  """
  def second_line_retry_prompt(line1, rejected_line, count) do
    """
    Generate the second line of a German haiku.

    First line:
    „#{line1}“

    Your previous attempt „#{rejected_line}“ had #{count} syllables, but the line must
    have EXACTLY 7 syllables. Write a DIFFERENT second line.

    Constraints:
    - Output exactly one line.
    - Output language: German.
    - Do not add quotation marks.
    - Do not add explanations.
    - Do not add any text before or after the line.
    - The line must contain EXACTLY 7 syllables.
    - Before answering, split every word into syllables and count them.
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
    |> String.replace(~r/^[“„””']+|[“„””']+$/u, "")
    |> String.trim()
  end

  # Strip overall whitespace from a 3-line haiku response.
  defp strip_haiku(text), do: String.trim(text)

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
