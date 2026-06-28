defmodule OwnershipAshChat.Study.Run do
  use Ash.Resource,
    otp_app: :ownership_ash_chat,
    domain: OwnershipAshChat.Study,
    data_layer: AshSqlite.DataLayer

  alias OwnershipAshChat.Study.Types

  sqlite do
    table "study_runs"
    repo OwnershipAshChat.Repo

    references do
      reference :session, on_delete: :delete, on_update: :update
    end
  end

  actions do
    defaults [:read, :destroy]

    # Set/seed the run's topic (participant's choice for :free, the assigned one for
    # :assigned) and stamp the run as started.
    update :set_topic do
      accept [:topic]
      change set_attribute(:started_at, &DateTime.utc_now/0)
    end

    # Append one user passage. For :with_ai runs still within the round limit, the
    # AI's reply is generated and appended too (ping-pong). Non-atomic: reads the
    # current transcript and may call the LLM.
    update :add_user_passage do
      require_atomic? false
      argument :text, :string, allow_nil?: false
      change OwnershipAshChat.Study.Run.Changes.AddPassage
    end

    # Store the run's Likert questionnaire answers (plan step #5). The map of
    # answers is validated against the `Likert` definition (all items present,
    # values within the scale). Non-atomic: the validation runs on the changeset.
    update :submit_likert do
      require_atomic? false
      accept [:likert]
      validate OwnershipAshChat.Study.Run.Validations.LikertAnswers
    end

    create :create do
      accept [
        :run_index,
        :kind,
        :topic_source,
        :ai_mode,
        :topic,
        :transcript,
        :final_haiku,
        :likert,
        :started_at,
        :completed_at,
        :variant,
        :source_run_index,
        :original_haiku,
        :modified_haiku
      ]

      argument :session_id, :uuid, allow_nil?: false

      change manage_relationship(:session_id, :session, type: :append)
    end
  end

  attributes do
    uuid_v7_primary_key :id

    # Presented order, 1..4 for writing runs. The modification run is tracked
    # separately via `kind` and `source_run_index`.
    attribute :run_index, :integer, public?: true

    attribute :kind, Types.RunKind do
      public? true
      allow_nil? false
      default :writing
    end

    attribute :topic_source, Types.TopicSource, public?: true
    attribute :ai_mode, Types.AiMode, public?: true
    attribute :topic, :string, public?: true

    # Ordered user + AI messages. JSON is only an export artifact (see AGENTS.md);
    # the transcript is stored embedded rather than relationally linked to Chat.
    attribute :transcript, {:array, :map} do
      public? true
      default []
    end

    attribute :final_haiku, :string, public?: true

    # Questionnaire answers, all items positively coded.
    attribute :likert, :map do
      public? true
      default %{}
    end

    attribute :started_at, :utc_datetime_usec, public?: true
    attribute :completed_at, :utc_datetime_usec, public?: true

    # Modification-run fields (kind == :modification only).
    attribute :variant, Types.Variant, public?: true
    attribute :source_run_index, :integer, public?: true
    attribute :original_haiku, :string, public?: true
    attribute :modified_haiku, :string, public?: true

    timestamps()
  end

  relationships do
    belongs_to :session, OwnershipAshChat.Study.Session do
      public? true
      allow_nil? false
    end
  end
end
