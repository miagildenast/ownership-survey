defmodule OwnershipAshChatWeb.StudyTexts do
  @moduledoc """
  All participant-facing study texts in one place: the study title, the intro
  instructions shown before the first run, and the task messages that guide the
  participant through each writing step in the chat window.

  Every string here is a **placeholder** — the final wording will be supplied by
  the study team later. Edit only this module to swap the copy.
  """

  alias OwnershipAshChat.Study.Run.Transcript

  @title "Dein, mein, unser? [Untertitel folgt]"

  @doc "The study title shown as the headline on every view."
  def title, do: @title

  @doc "Heading of the instruction panel shown before the first run."
  def intro_heading, do: "Willkommen zur Studie"

  @doc "Instruction text shown before the first run (placeholder)."
  def intro_text do
    """
    Sie schreiben in dieser Studie vier kurze Haikus – teilweise gemeinsam mit
    einer KI, teilweise allein. Nach jeder Runde beantworten Sie einen kurzen
    Fragebogen. Zum Abschluss sehen Sie eine KI-Überarbeitung eines Ihrer
    Haikus und bewerten auch diese. Klicken Sie auf „Start“, um zu beginnen.
    """
  end

  @doc """
  The task message guiding the participant's next line, as a pure function of the
  run's condition (`topic_source` × `ai_mode`) and how many transcript lines exist.

  Returns `nil` when the participant has nothing to do (run complete or AI turn).
  All texts are placeholders.
  """
  def task_message(run), do: task_message(run, length(run.transcript || []))

  @doc """
  The task message for the line at the given 0-based position (used to re-render
  already-answered tasks in the chat history). `nil` for AI turns and positions
  beyond the run's lines.
  """
  def task_message(run, position) do
    if Transcript.ai_turn?(run, position) do
      nil
    else
      task_message(run.topic_source, run.ai_mode, position, run.topic)
    end
  end

  defp task_message(:assigned, :without_ai, 0, topic),
    do: "Schreiben Sie ein Haiku zum Thema „#{topic}“. Beginnen Sie mit der ersten Zeile."

  defp task_message(:free, :without_ai, 0, _topic),
    do: "Schreiben Sie ein Haiku zu einem Thema Ihrer Wahl. Beginnen Sie mit der ersten Zeile."

  defp task_message(_topic_source, :without_ai, 1, _topic),
    do: "Schreiben Sie nun die zweite Zeile."

  defp task_message(_topic_source, :without_ai, 2, _topic),
    do: "Schreiben Sie zum Abschluss die dritte Zeile."

  defp task_message(:assigned, :with_ai, 1, topic),
    do:
      "Die KI hat die erste Zeile zum Thema „#{topic}“ geschrieben. " <>
        "Schreiben Sie nun die zweite Zeile – die dritte Zeile ergänzt die KI."

  defp task_message(:free, :with_ai, 0, _topic),
    do:
      "Schreiben Sie die erste Zeile eines Haikus zu einem Thema Ihrer Wahl – " <>
        "die nächste Zeile wird die KI generieren."

  defp task_message(:free, :with_ai, 2, _topic),
    do: "Schreiben Sie zum Abschluss die dritte Zeile des Haikus."

  defp task_message(_topic_source, _ai_mode, _position, _topic), do: nil
end
