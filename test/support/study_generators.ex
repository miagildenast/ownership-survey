defmodule OwnershipAshChat.StudyGenerators do
  @moduledoc """
  `Ash.Generator`-based fixtures for the Study domain resources.
  """
  use Ash.Generator

  alias OwnershipAshChat.Study

  def session(opts \\ []) do
    changeset_generator(
      Study.Session,
      :create,
      defaults: [
        case_id: "case-#{System.unique_integer([:positive])}",
        topic_source_order: [:free, :assigned]
      ],
      overrides: opts
    )
  end

  def run(opts \\ []) do
    # Accept a pre-built session, otherwise generate one.
    {session_id, opts} =
      Keyword.pop_lazy(opts, :session_id, fn -> generate(session()).id end)

    changeset_generator(
      Study.Run,
      :create,
      defaults: [
        run_index: sequence(:run_index, & &1),
        kind: :writing,
        topic_source: :free,
        ai_mode: :with_ai,
        session_id: session_id
      ],
      overrides: opts
    )
  end
end
