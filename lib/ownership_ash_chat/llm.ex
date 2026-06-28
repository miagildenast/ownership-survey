defmodule OwnershipAshChat.LLM do
  @moduledoc "Central LLM model/options resolution (prod: Anthropic, dev: local LM Studio)."

  def model, do: config()[:model]
  def req_llm_opts, do: Keyword.get(config(), :req_llm_opts, [])

  defp config, do: Application.fetch_env!(:ownership_ash_chat, :llm)
end
