defmodule OwnershipAshChat.LLM do
  @moduledoc "Central LLM model/options resolution (prod: Anthropic, dev: local LM Studio)."

  @system_preamble """
  You are a text generation component used in a scientific experiment.
  Follow the instructions exactly.
  Your FINAL answer must contain only the requested text — no explanations,
  comments, formatting notes, or additional content.
  You may reason internally before producing the final answer; that reasoning
  is not part of the final answer.
  The output language is German unless explicitly stated otherwise.
  """

  def model, do: config()[:model]
  def req_llm_opts, do: Keyword.get(config(), :req_llm_opts, [])

  @doc """
  Global system preamble that stands above every task-specific prompt. Prepend it
  to each task's system message so all LLM calls share the same framing.
  """
  def system_preamble, do: @system_preamble

  defp config, do: Application.fetch_env!(:ownership_ash_chat, :llm)
end
