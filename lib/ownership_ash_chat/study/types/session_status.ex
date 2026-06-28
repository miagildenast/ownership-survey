defmodule OwnershipAshChat.Study.Types.SessionStatus do
  use Ash.Type.Enum, values: [:in_progress, :completed, :aborted]
end
