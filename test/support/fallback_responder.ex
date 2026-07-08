defmodule OwnershipAshChat.Study.FallbackResponder do
  @moduledoc """
  Test stub that mimics the ping-pong loop giving up on the syllable target:
  it returns `{:fallback, line, candidates}`, the same shape
  `PingPong.generate_passage/2` produces after exhausting its attempts. Wired in via
  `:study_responder` in individual tests that exercise the fallback path.
  """

  def reply(_run, _opts) do
    {:fallback, "Kurze Zeile", ["Kurze Zeile", "Andere Zeile"]}
  end
end
