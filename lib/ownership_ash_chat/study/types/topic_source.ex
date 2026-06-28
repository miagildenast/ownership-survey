defmodule OwnershipAshChat.Study.Types.TopicSource do
  use Ash.Type.Enum, values: [:assigned, :free]
end
