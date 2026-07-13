defmodule OwnershipAshChat.LLM do
  @moduledoc "Central LLM model/options resolution (prod: Anthropic, dev: local LM Studio)."

  def model, do: config()[:model]
  def req_llm_opts, do: Keyword.get(config(), :req_llm_opts, [])

  @doc """
  Global system preamble that stands above every task-specific prompt. Prepend it
  to each task's system message so all LLM calls share the same framing.

  Configured in the study config file (`priv/study/config.yml`, `llm.system_preamble`).
  """
  def system_preamble, do: OwnershipAshChat.Study.Config.system_preamble()

  defp config, do: Application.fetch_env!(:ownership_ash_chat, :llm)
end
