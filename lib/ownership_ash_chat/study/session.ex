defmodule OwnershipAshChat.Study.Session do
  use Ash.Resource,
    otp_app: :ownership_ash_chat,
    domain: OwnershipAshChat.Study,
    data_layer: AshPostgres.DataLayer

  alias OwnershipAshChat.Study.Types

  postgres do
    table "study_sessions"
    repo OwnershipAshChat.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:case_id, :topic_source_order, :metadata]
    end
  end

  attributes do
    # The primary key doubles as the session_id UUID shown at the end for
    # later matching with the upstream study tool.
    uuid_v7_primary_key :id

    attribute :case_id, :string do
      public? true
    end

    attribute :topic_source_order, {:array, Types.TopicSource} do
      public? true
    end

    attribute :status, Types.SessionStatus do
      public? true
      allow_nil? false
      default :in_progress
    end

    attribute :started_at, :utc_datetime_usec, public?: true
    attribute :completed_at, :utc_datetime_usec, public?: true

    attribute :metadata, :map do
      public? true
      default %{}
    end

    timestamps()
  end

  relationships do
    has_many :runs, OwnershipAshChat.Study.Run do
      public? true
    end
  end
end
