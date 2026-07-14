defmodule OwnershipAshChat.Study.Config do
  @moduledoc """
  Loads and exposes the study configuration from a single YAML file
  (`priv/study/config.yml` by default).

  The file is read, validated (via the `Ash.TypedStruct` schema in
  `#{inspect(__MODULE__)}.Schema`) and normalized into fast lookup maps **once at
  boot** (`OwnershipAshChat.Application.start/2` calls `load!/0` before the
  supervisor starts). The normalized data lives in `:persistent_term`, so the
  per-request accessors below are cheap, no-copy reads.

  Invalid or missing configuration raises during `load!/0`, aborting boot with a
  clear error — a misconfigured study never runs half-broken.

  The file location can be overridden (e.g. for tests) via:

      config :ownership_ash_chat, :study_config_path, "path/to/config.yml"
  """

  alias OwnershipAshChat.Study.Config.Schema.StudyConfig

  @persistent_term_key {__MODULE__, :config}

  @doc "Resolve the configured config-file path."
  def path do
    Application.get_env(:ownership_ash_chat, :study_config_path) ||
      Application.app_dir(:ownership_ash_chat, "priv/study/config.yml")
  end

  @doc """
  Read, validate and cache the study config from `path/0` (or an explicit path).

  Raises `RuntimeError` if the file is missing/unparseable, or `Ash.Error` (from
  `StudyConfig.new!/1`) if a field is missing or of the wrong shape. On success the
  normalized config is stored in `:persistent_term` and returned.
  """
  def load!(file \\ path()) do
    normalized =
      file
      |> read_yaml!()
      |> StudyConfig.new!()
      |> normalize()

    :persistent_term.put(@persistent_term_key, normalized)
    normalized
  end

  @doc "Reload the config from disk, replacing the cached copy. Dev/test convenience."
  def reload, do: load!()

  # --- accessors -------------------------------------------------------------

  def title, do: fetch(:title)
  def intro_heading, do: fetch(:intro_heading)
  def intro_text, do: fetch(:intro_text)
  def system_preamble, do: fetch(:system_preamble)
  def retry_suffix, do: fetch(:retry_suffix)
  def modification_prompt_base, do: fetch(:modification_base)

  @doc "Task guidance text for a condition + 0-based position, or `nil` if none."
  def task_message(topic_source, ai_mode, position),
    do: Map.get(fetch(:task_messages), {topic_source, ai_mode, position})

  @doc "Map of 0-based line position => syllable target."
  def syllable_targets, do: fetch(:syllable_targets)
  def syllable_target(position), do: Map.fetch!(syllable_targets(), position)

  @doc "LLM base prompt template for the AI line at the given 0-based position."
  def line_prompt(position), do: Map.fetch!(fetch(:line_prompts), position)

  @doc "Modification change-description template for variant `:a` or `:b`."
  def modification_change(variant), do: Map.fetch!(fetch(:modification_change), variant)

  @doc "Questionnaire items as `[%{key: String.t(), prompt: String.t()}]`, in order."
  def likert_items, do: fetch(:likert_items)

  @doc "Questionnaire haiku framing copy as `%{before:, after:}` (Markdown strings)."
  def haiku_intro, do: fetch(:haiku_intro)

  @doc "Open-ended questions (modification run) as `[%{key:, prompt:}]`, in order."
  def open_questions, do: fetch(:open_questions)

  @doc "The rating scale as a range (min..max)."
  def likert_scale, do: fetch(:scale_min)..fetch(:scale_max)

  @doc "Map of scale value => human label."
  def likert_scale_labels, do: fetch(:scale_labels)

  @doc "A screen's copy (`:pre_modification` | `:all_done`) as `%{heading:, body:, skip:}`."
  def screen(name), do: Map.fetch!(fetch(:screens), name)

  @doc "Whether the pre-modification transition card should be skipped (auto-advance to the modification run)."
  def skip_pre_modification?, do: screen(:pre_modification).skip

  # --- loading internals -----------------------------------------------------

  defp fetch(key) do
    :persistent_term.get(@persistent_term_key)
    |> Map.fetch!(key)
  rescue
    ArgumentError ->
      raise "Study config not loaded. Call #{inspect(__MODULE__)}.load!/0 at boot."
  end

  defp read_yaml!(file) do
    case YamlElixir.read_from_file(file) do
      {:ok, %{} = data} ->
        data

      {:ok, other} ->
        raise "Study config #{file} must be a YAML mapping, got: #{inspect(other)}"

      {:error, reason} ->
        raise "Could not read study config #{file}: #{inspect(reason)}"
    end
  end

  # Fold the validated schema struct into the flat lookup maps the accessors use.
  defp normalize(%StudyConfig{} = c) do
    %{
      title: c.title,
      intro_heading: c.intro.heading,
      intro_text: c.intro.body,
      task_messages:
        Map.new(c.task_messages, &{{&1.topic_source, &1.ai_mode, &1.position}, &1.text}),
      syllable_targets:
        c.syllable_targets |> Enum.with_index() |> Map.new(fn {t, i} -> {i, t} end),
      system_preamble: c.llm.system_preamble,
      retry_suffix: c.llm.retry_suffix,
      line_prompts: Map.new(c.llm.line_prompts, &{&1.position, &1.template}),
      modification_base: c.llm.modification.base,
      modification_change: %{
        a: c.llm.modification.change_descriptions.a,
        b: c.llm.modification.change_descriptions.b
      },
      haiku_intro: %{
        before: c.questionnaire.haiku_intro.before,
        after: c.questionnaire.haiku_intro.after
      },
      likert_items: Enum.map(c.questionnaire.items, &%{key: &1.key, prompt: &1.prompt}),
      open_questions:
        Enum.map(c.questionnaire.open_questions, &%{key: &1.key, prompt: &1.prompt}),
      scale_min: c.questionnaire.scale.min,
      scale_max: c.questionnaire.scale.max,
      scale_labels: Map.new(c.questionnaire.scale.labels, &{&1.value, &1.label}),
      screens: %{
        pre_modification: screen_map(c.screens.pre_modification),
        all_done: screen_map(c.screens.all_done)
      }
    }
  end

  defp screen_map(%{heading: heading, body: body, skip: skip}),
    do: %{heading: heading, body: body, skip: skip}
end
