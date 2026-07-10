defmodule OwnershipAshChat.Study.PingPong do
  @moduledoc """
  Ping-pong (`:with_ai`) writing helper for study runs.

  Generates the AI's next passage from a run's current transcript by reusing the
  central LLM config (`OwnershipAshChat.LLM`) and `ReqLLM`. The chat's
  `Chat.Message.Changes.Respond` persistence is intentionally NOT reused — the
  study stores the transcript embedded on the run, not as `Chat.Message` rows.

  Which lines the AI writes depends on the run's condition (5-7-5 targets):

    * `:free && :with_ai`     → `[user, AI, user]` — the AI writes line 2
      (7 syllables) from the participant's first line. There is no topic; the
      first line sets it implicitly.
    * `:assigned && :with_ai` → `[AI, user, AI]` — the AI opens with line 1
      (5 syllables) from the assigned topic and closes with line 3 (5 syllables).

  The AI's line for a given turn is derived purely from the transcript length:
  position 0 → first line, 1 → second line, 2 → third line. Participant lines are
  NEVER syllable-validated — only generated lines go through the retry loop.

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

  # Haiku syllable targets by 0-based line position (5-7-5).
  @line_targets %{0 => 5, 1 => 7, 2 => 5}

  @doc """
  Total number of lines (passages) a writing run holds before it auto-completes.

  Three lines regardless of condition; see the moduledoc for who writes which line.
  """
  def lines, do: Application.get_env(:ownership_ash_chat, :ping_pong_lines, 3)

  @doc """
  Max number of LLM attempts to produce a line with the target syllable count before
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
  Generate the AI's next haiku line from the run's transcript.

  The line position is the current transcript length (0-based): position 0 is the
  opening line prompted from `run.topic` (assigned runs), position 1 the second
  line from line 1, position 2 the closing line from lines 1 and 2. Each generated
  line is validated against its target syllable count (`Syllables.count/1`); on a
  mismatch the model is re-prompted with corrective feedback, up to
  `line_attempts/0` times.

  Returns:

    * `{:ok, line}` — a line with the target syllable count was produced.
    * `{:fallback, line, candidates}` — no attempt hit the target; `line` is the
      candidate closest to the target and `candidates` lists every tried line, in
      order. Callers surface this so the participant knows the line is unreliable.

  Text generation is injectable (per prompt) via `opts[:line_generator]` or the
  `:study_line_generator` app env, mirroring the `:study_responder` pattern so tests
  can drive the loop without a live model.
  """
  def generate_passage(run, opts \\ []) do
    transcript = run.transcript || []
    position = length(transcript)
    prompts = prompt_builders(run, transcript, position)
    target = Map.fetch!(@line_targets, position)
    generator = line_generator(opts)
    attempt_line(prompts, target, generator, line_attempts(opts), nil, [])
  end

  # {base prompt, retry-prompt builder} for the AI line at the given position.
  defp prompt_builders(run, _transcript, 0) do
    topic = run.topic || ""
    {first_line_prompt(topic), &first_line_retry_prompt(topic, &1, &2)}
  end

  defp prompt_builders(_run, transcript, 1) do
    line1 = line_text(transcript, 0)
    {second_line_prompt(line1), &second_line_retry_prompt(line1, &1, &2)}
  end

  defp prompt_builders(_run, transcript, 2) do
    line1 = line_text(transcript, 0)
    line2 = line_text(transcript, 1)
    {third_line_prompt(line1, line2), &third_line_retry_prompt(line1, line2, &1, &2)}
  end

  defp attempt_line({base, retry} = prompts, target, generator, remaining, previous, candidates) do
    attempt_no = length(candidates) + 1

    prompt =
      case previous do
        nil -> base
        {bad_line, count} -> retry.(bad_line, count)
      end

    Logger.debug(
      "PingPong attempt #{attempt_no}: target #{target} syllables, prompt: #{inspect(prompt)}"
    )

    line = generator |> invoke_generator(prompt) |> strip_line()
    count = Syllables.count(line)

    Logger.debug(
      "PingPong attempt #{attempt_no} response: #{inspect(line)} (#{count} syllables, target #{target})"
    )

    candidates = candidates ++ [line]

    cond do
      count == target ->
        Logger.debug("PingPong attempt #{attempt_no}: accepted #{inspect(line)}")
        {:ok, line}

      remaining <= 1 ->
        Logger.warning(
          "PingPong: no valid #{target}-syllable line after " <>
            "#{length(candidates)} attempts; using closest candidate " <>
            "#{inspect(closest_candidate(candidates, target))}. Tried: #{inspect(candidates)}"
        )

        {:fallback, closest_candidate(candidates, target), candidates}

      true ->
        Logger.debug(
          "PingPong retry: line #{inspect(line)} has #{count} syllables (target #{target}); " <>
            "re-prompting, #{remaining - 1} attempt(s) left"
        )

        attempt_line(prompts, target, generator, remaining - 1, {line, count}, candidates)
    end
  end

  defp closest_candidate(candidates, target) do
    Enum.min_by(candidates, fn line -> abs(Syllables.count(line) - target) end)
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

    Logger.debug("PingPong LLM request (model #{inspect(LLM.model())}): #{inspect(prompt)}")

    case ReqLLM.generate_text(
           ReqLLM.model!(LLM.model()),
           Context.new(messages),
           LLM.req_llm_opts()
         ) do
      {:ok, response} ->
        text = response |> ReqLLM.Response.text() |> to_string()
        Logger.debug("PingPong LLM response: #{inspect(text)}")
        text

      {:error, reason} ->
        Logger.error("PingPong LLM call failed: #{inspect(reason)}")
        "error im llm"
    end
  end

  @doc """
  Resolve and invoke the configured modification responder, producing a new version
  of a single haiku line. Defaults to `generate_modification/4`. Injectable via:

      config :ownership_ash_chat, :study_modification_responder, {MyStub, :reply}

  Only the participant's own line is ever modified (`line_index`, 0-based); the full
  `haiku` is passed for context. The responder returns just the new line text; the
  caller splices it back into the haiku so every other line stays byte-identical.
  """
  def respond_modification(haiku, variant, line_index, opts \\ []) do
    {mod, fun} =
      Application.get_env(
        :ownership_ash_chat,
        :study_modification_responder,
        {__MODULE__, :generate_modification}
      )

    apply(mod, fun, [haiku, variant, line_index, opts])
  end

  @doc """
  Produce a variant-modified version of a single haiku line, validated against its
  5-7-5 syllable target (`@line_targets[line_index]`) with the same reprompt loop the
  generated lines use (`attempt_line/6` + `Syllables.count/1`).

  Returns the new line text (a single line). When no attempt hits the target within
  `line_attempts/0` tries, returns the candidate whose syllable count is closest to
  the target — never a tuple, so the caller can splice it straight into the haiku.

  Text generation is injectable via `opts[:line_generator]` / the `:study_line_generator`
  app env, and the attempt budget via `opts[:line_attempts]`, mirroring
  `generate_passage/2` so tests can drive the loop without a live model.
  """
  def generate_modification(haiku, variant, line_index, opts \\ []) do
    target = Map.fetch!(@line_targets, line_index)
    base = modification_prompt(haiku, variant, line_index)
    retry = &modification_retry_prompt(haiku, variant, line_index, &1, &2)
    generator = line_generator(opts)

    Logger.debug(
      "PingPong modification (variant #{inspect(variant)}, line #{line_index}, " <>
        "target #{target} syllables, model #{inspect(LLM.model())})"
    )

    case attempt_line({base, retry}, target, generator, line_attempts(opts), nil, []) do
      {:ok, line} -> line
      {:fallback, line, _candidates} -> line
    end
  end

  @doc """
  Prompt asking the model to modify one line of a haiku (`line_index`, 0-based).

  Variant `:a` = change exactly one word in that line, `:b` = replace the whole line.
  The full haiku is shown for context; the model must output only the single new
  line, so the caller can splice it in without disturbing the other lines.
  """
  def modification_prompt(haiku, variant, line_index) do
    original_line = line_at(haiku, line_index)
    line_no = line_index + 1
    target = Map.fetch!(@line_targets, line_index)

    change_desc =
      case variant do
        :a -> "Change exactly one word in line #{line_no}."
        :b -> "Replace line #{line_no} entirely with a new line."
      end

    """
    Here is a German haiku:

    #{haiku}

    Modify only line #{line_no}: „#{original_line}“
    Modification: #{change_desc}

    Constraints:
    - Output language: German.
    - Output ONLY the new version of line #{line_no} — a single line.
    - Keep the other lines out of your answer.
    - The new line must contain EXACTLY #{target} syllables.
    - NEVER return a line with more or fewer than #{target} syllables.
    - Before answering, split every word into syllables and count them.
    - Do not mark syllable boundaries in the output: no hyphens inside words, write every word normally.
    - Do not add quotation marks, explanations, or any additional text.
    """
  end

  @doc """
  Corrective modification prompt used after a rejected attempt: names the rejected line
  and its measured syllable count so the model gets concrete feedback instead of
  re-rolling blind. Otherwise mirrors the base `modification_prompt/3`.
  """
  def modification_retry_prompt(haiku, variant, line_index, rejected_line, count) do
    line_no = line_index + 1
    target = Map.fetch!(@line_targets, line_index)

    modification_prompt(haiku, variant, line_index) <>
      """

      Your previous attempt „#{rejected_line}“ had #{count} syllables, but line #{line_no} \
      must have EXACTLY #{target} syllables. Write a DIFFERENT version.
      """
  end

  @doc "Replace the 0-based line at `index` in a multi-line haiku with `new_line`."
  def replace_line(haiku, index, new_line) do
    haiku
    |> String.split("\n")
    |> List.replace_at(index, to_string(new_line))
    |> Enum.join("\n")
  end

  defp line_at(haiku, index) do
    haiku |> String.split("\n") |> Enum.at(index, "") |> to_string()
  end

  @doc """
  Prompt asking the model for the opening haiku line (5 syllables) on the assigned
  topic. Used as the AI's first turn in `:assigned && :with_ai` runs.
  """
  def first_line_prompt(topic) do
    """
    Generate the first line of a German haiku on the topic „#{topic}“.

    Constraints:
    - Output exactly one line.
    - Output language: German.
    - Do not add quotation marks.
    - Do not add explanations.
    - Do not add any text before or after the line.
    - The line must contain EXACTLY 5 syllables.
    - NEVER return a line with more or fewer than 5 syllables.
    - Before answering, split every word into syllables and count them.
    - Do not mark syllable boundaries in the output: no hyphens inside words, write every word normally.
    - Return only the first line.
    """
  end

  @doc """
  Corrective first-line prompt used after a rejected attempt: it names the rejected
  line and its measured syllable count so the model gets concrete feedback instead
  of re-rolling blind.
  """
  def first_line_retry_prompt(topic, rejected_line, count) do
    """
    Generate the first line of a German haiku on the topic „#{topic}“.

    Your previous attempt „#{rejected_line}“ had #{count} syllables, but the line must
    have EXACTLY 5 syllables. Write a DIFFERENT first line.

    Constraints:
    - Output exactly one line.
    - Output language: German.
    - Do not add quotation marks.
    - Do not add explanations.
    - Do not add any text before or after the line.
    - The line must contain EXACTLY 5 syllables.
    - Before answering, split every word into syllables and count them.
    - Do not mark syllable boundaries in the output: no hyphens inside words, write every word normally.
    - Return only the first line.
    """
  end

  @doc """
  The literal prompt asking the model for the second haiku line (7 syllables),
  given line 1. Used as the AI's turn in `:free && :with_ai` runs, where line 1
  (written by the human) is the only topic signal — by design, `:free` runs have
  no explicit topic.
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
    - Do not mark syllable boundaries in the output: no hyphens inside words, write every word normally.
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
    - Do not mark syllable boundaries in the output: no hyphens inside words, write every word normally.
    - Return only the second line.
    """
  end

  @doc """
  Prompt asking the model for the closing haiku line (5 syllables), given lines 1
  and 2. Used as the AI's final turn in `:assigned && :with_ai` runs.
  """
  def third_line_prompt(line1, line2) do
    """
    Generate the third line of a German haiku.

    First line:
    „#{line1}“

    Second line:
    „#{line2}“

    Constraints:
    - Output exactly one line.
    - Output language: German.
    - Do not add quotation marks.
    - Do not add explanations.
    - Do not add any text before or after the line.
    - The line must contain EXACTLY 5 syllables.
    - NEVER return a line with more or fewer than 5 syllables.
    - Before answering, split every word into syllables and count them.
    - Do not mark syllable boundaries in the output: no hyphens inside words, write every word normally.
    - Return only the third line.
    """
  end

  @doc """
  Corrective third-line prompt used after a rejected attempt: it names the rejected
  line and its measured syllable count so the model gets concrete feedback instead
  of re-rolling blind.
  """
  def third_line_retry_prompt(line1, line2, rejected_line, count) do
    """
    Generate the third line of a German haiku.

    First line:
    „#{line1}“

    Second line:
    „#{line2}“

    Your previous attempt „#{rejected_line}“ had #{count} syllables, but the line must
    have EXACTLY 5 syllables. Write a DIFFERENT third line.

    Constraints:
    - Output exactly one line.
    - Output language: German.
    - Do not add quotation marks.
    - Do not add explanations.
    - Do not add any text before or after the line.
    - The line must contain EXACTLY 5 syllables.
    - Before answering, split every word into syllables and count them.
    - Do not mark syllable boundaries in the output: no hyphens inside words, write every word normally.
    - Return only the third line.
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

  defp line_text(transcript, index) do
    transcript |> Enum.at(index) |> text()
  end

  defp text(%{"text" => text}), do: to_string(text)
  defp text(%{text: text}), do: to_string(text)
  defp text(_), do: ""
end
