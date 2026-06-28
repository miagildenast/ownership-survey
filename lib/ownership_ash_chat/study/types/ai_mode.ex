defmodule OwnershipAshChat.Study.Types.AiMode do
  use Ash.Type.Enum, values: [:with_ai, :without_ai]
end
