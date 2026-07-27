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

    # Mark the run as started when it first becomes active: stamps started_at and,
    # for :assigned/:with_ai runs, generates the AI's opening line. Idempotent.
    # Non-atomic: reads the current record and may call the LLM.
    update :begin_run do
      require_atomic? false
      change OwnershipAshChat.Study.Run.Changes.BeginRun
    end

    # Append one user passage. Pending AI turns around it are generated and appended
    # too (ping-pong; which lines are AI turns depends on the condition). Non-atomic:
    # reads the current transcript and may call the LLM.
    update :add_user_passage do
      require_atomic? false
      argument :text, :string, allow_nil?: false
      change OwnershipAshChat.Study.Run.Changes.AddPassage
    end

    # Store the run's Likert questionnaire answers (plan step #5) and, for the
    # modification run, its open-ended free-text answers. The Likert map is validated
    # against the `Likert` definition (all items present, values within the scale);
    # the open answers against the configured open questions (modification run only,
    # all present and non-blank; empty on writing runs). Non-atomic: the validations
    # run on the changeset (and OpenEndedAnswers reads the record's `kind`).
    update :submit_likert do
      require_atomic? false
      accept [:likert, :open_answers]
      validate OwnershipAshChat.Study.Run.Validations.LikertAnswers
      validate OwnershipAshChat.Study.Run.Validations.OpenEndedAnswers
    end

    # Balancing input (`Study.Balance`): the two runs per session that carry the drawn
    # writing sequence — run 1 gives the first block's topic_source *and* its leading
    # ai_mode, run 3 the second block's leading ai_mode. Aborted sessions don't count.
    read :randomization_marks do
      prepare build(select: [:session_id, :run_index, :topic_source, :ai_mode])

      filter expr(kind == :writing and run_index in [1, 3] and session.status != :aborted)
    end

    # Balancing input (`Study.Balance`): the assigned modification variants. Carries
    # `session_id` so a caller can split off one session's own draw and count the rest —
    # the "session completed" notification reports the split as it was *before* that draw.
    read :variant_marks do
      prepare build(select: [:session_id, :variant])

      filter expr(kind == :modification and not is_nil(variant) and session.status != :aborted)
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
        :open_answers,
        :started_at,
        :completed_at,
        :variant,
        :source_run_index,
        :modified_line_index,
        :original_haiku,
        :modified_haiku
      ]

      argument :session_id, :uuid, allow_nil?: false

      change manage_relationship(:session_id, :session, type: :append)
    end

    # Build the fifth run from the session's completed writing runs: picks the best
    # run + a variant, rewrites the participant's first line via the LLM, and stores
    # the modification fields. Non-atomic: reads the writing runs and calls the LLM.
    create :create_modification do
      argument :session_id, :uuid, allow_nil?: false

      change manage_relationship(:session_id, :session, type: :append)
      change OwnershipAshChat.Study.Run.Changes.CreateModification
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

    # Open-ended free-text answers, string-keyed (modification run only; empty for
    # writing runs). Keys mirror the configured open questions.
    attribute :open_answers, :map do
      public? true
      default %{}
    end

    attribute :started_at, :utc_datetime_usec, public?: true
    attribute :completed_at, :utc_datetime_usec, public?: true

    # Modification-run fields (kind == :modification only).
    attribute :variant, Types.Variant, public?: true
    attribute :source_run_index, :integer, public?: true
    # 0-based index of the (participant-written) line that was rewritten.
    attribute :modified_line_index, :integer, public?: true
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
