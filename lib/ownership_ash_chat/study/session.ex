defmodule OwnershipAshChat.Study.Session do
  use Ash.Resource,
    otp_app: :ownership_ash_chat,
    domain: OwnershipAshChat.Study,
    data_layer: AshSqlite.DataLayer

  alias OwnershipAshChat.Study.Types

  sqlite do
    table "study_sessions"
    repo OwnershipAshChat.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:case_id, :topic_source_order, :metadata]
    end

    # Token entry: the upstream tool sends the `case_id` via `/start?case_id=…`.
    # Upsert on `case_id` so a returning participant resumes the same session
    # (same `session_id`) instead of creating a duplicate.
    create :start do
      accept [:case_id, :metadata]
      upsert? true
      upsert_identity :unique_case_id
      # On resume, leave the existing record untouched and return it as-is.
      upsert_fields []
      # Draw randomization + seed the 4 writing runs on fresh insert; idempotent on
      # resume (see SeedRuns).
      change OwnershipAshChat.Study.Session.Changes.SeedRuns
    end

    # Mark the session complete after the modification run's Likert is submitted
    # (plan step #7). Sets status :completed and stamps completed_at.
    update :complete do
      change set_attribute(:status, :completed)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
    end

    # Export reads (step 8): JSON is only an on-demand artifact, generated from
    # these read actions which load the runs relationship. Serialization lives in
    # `OwnershipAshChat.Study.Export`.
    read :export do
      get? true
      prepare build(load: [:runs])
    end

    read :export_all do
      argument :status, Types.SessionStatus, allow_nil?: true

      prepare build(load: [:runs])

      filter expr(is_nil(^arg(:status)) or status == ^arg(:status))
    end
  end

  attributes do
    # The primary key doubles as the session_id UUID shown at the end for
    # later matching with the upstream study tool.
    uuid_v7_primary_key :id

    attribute :case_id, :string do
      public? true
      allow_nil? false
      constraints min_length: 1
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

  identities do
    identity :unique_case_id, [:case_id]
  end
end
