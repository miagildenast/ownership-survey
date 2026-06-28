defmodule OwnershipAshChat.Study.PingPongStub do
  @moduledoc """
  Deterministic stand-in for `OwnershipAshChat.Study.PingPong.generate_passage/2`,
  wired in via `:study_responder` config in the test env so ping-pong runs never hit
  a live LLM.
  """

  @reply "KI-Zeile"

  @doc "Fixed AI passage. Matches the `respond/2` responder contract (run, opts)."
  def reply(_run, _opts), do: @reply

  @doc "The fixed text this stub returns, for assertions."
  def text, do: @reply
end
