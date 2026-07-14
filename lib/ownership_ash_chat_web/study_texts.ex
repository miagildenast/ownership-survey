defmodule OwnershipAshChatWeb.StudyTexts do
  @moduledoc """
  Participant-facing study copy: the study title, the intro instructions shown
  before the first run, and the task messages that guide the participant through
  each writing step in the chat window.

  All strings come from the study configuration file (`priv/study/config.yml`) via
  `OwnershipAshChat.Study.Config`; this module only maps a run's condition to the
  right configured text. Edit the YAML to change the copy.
  """

  alias OwnershipAshChat.Study.Config

  @doc "The study title shown as the headline on every view."
  def title, do: Config.title()

  @doc "Heading of the instruction panel shown before the first run."
  def intro_heading, do: Config.intro_heading()

  @doc "Instruction text (Markdown) shown before the first run."
  def intro_text, do: Config.intro_text()

  @doc """
  The questionnaire's haiku framing copy as `%{before:, after:}` (Markdown), shown
  above and below the haiku on the post-run questionnaire screen. Either part may be
  blank to omit it.
  """
  def haiku_intro, do: Config.haiku_intro()

  @doc """
  The task message guiding the participant's next line, as a pure function of the
  run's condition (`topic_source` × `ai_mode`) and how many transcript lines exist.

  Returns `nil` when the participant has nothing to do (run complete or AI turn).
  """
  def task_message(run), do: task_message(run, length(run.transcript || []))

  @doc """
  The task message for the line at the given 0-based position (used to re-render
  tasks in the chat history). `nil` for positions without a configured message.

  A message may be configured at a position the AI writes (e.g. `assigned/with_ai`
  position 0): it is then shown first, above the AI's opening line, to frame the run.
  """
  def task_message(run, position) do
    Config.task_message(run.topic_source, run.ai_mode, position)
    |> interpolate_topic(run.topic)
  end

  defp interpolate_topic(nil, _topic), do: nil
  defp interpolate_topic(text, topic), do: String.replace(text, "{topic}", to_string(topic))
end
