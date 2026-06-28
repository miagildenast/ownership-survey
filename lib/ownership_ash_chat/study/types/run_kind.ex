defmodule OwnershipAshChat.Study.Types.RunKind do
  use Ash.Type.Enum, values: [:writing, :modification]
end
