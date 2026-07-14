defmodule OwnershipAshChat.Study.Config.Schema do
  @moduledoc """
  `Ash.TypedStruct` schema for the study configuration file (`priv/study/config.yml`).

  The parsed YAML (string-keyed maps) is cast + validated by `StudyConfig.new!/1`,
  which raises an `Ash.Error` naming the offending field on invalid input — the
  fail-fast signal used at boot (see `OwnershipAshChat.Study.Config`).

  Sections that are logically maps with dynamic keys (task messages, line prompts,
  scale labels) are modelled as **arrays of fixed-shape entries** here, because
  `Ash.TypedStruct` describes fixed-shape structs, not arbitrary-key maps. `Config`
  folds these arrays into fast lookup maps after casting.

  Leaf modules are defined before the modules that reference them so the field-type
  transformation can resolve each nested type at compile time.
  """

  defmodule LikertItem do
    @moduledoc false
    use Ash.TypedStruct

    typed_struct do
      field :key, :string, allow_nil?: false
      field :prompt, :string, allow_nil?: false
    end
  end

  defmodule OpenQuestion do
    @moduledoc false
    use Ash.TypedStruct

    typed_struct do
      field :key, :string, allow_nil?: false
      field :prompt, :string, allow_nil?: false
    end
  end

  defmodule ScaleLabel do
    @moduledoc false
    use Ash.TypedStruct

    typed_struct do
      field :value, :integer, allow_nil?: false
      field :label, :string, allow_nil?: false
    end
  end

  defmodule Scale do
    @moduledoc false
    use Ash.TypedStruct

    typed_struct do
      field :min, :integer, allow_nil?: false
      field :max, :integer, allow_nil?: false
      field :labels, {:array, ScaleLabel}, allow_nil?: false, constraints: [min_length: 1]
    end
  end

  defmodule Intro do
    @moduledoc false
    use Ash.TypedStruct

    typed_struct do
      field :heading, :string, allow_nil?: false
      field :body, :string, allow_nil?: false
    end
  end

  defmodule Screen do
    @moduledoc false
    use Ash.TypedStruct

    typed_struct do
      field :heading, :string, allow_nil?: false
      field :body, :string, allow_nil?: false
      field :skip, :boolean, default: false
    end
  end

  defmodule Screens do
    @moduledoc false
    use Ash.TypedStruct

    typed_struct do
      field :pre_modification, Screen, allow_nil?: false
      field :all_done, Screen, allow_nil?: false
    end
  end

  defmodule TaskMessage do
    @moduledoc false
    use Ash.TypedStruct

    typed_struct do
      field :topic_source, :atom, allow_nil?: false, constraints: [one_of: [:assigned, :free]]
      field :ai_mode, :atom, allow_nil?: false, constraints: [one_of: [:with_ai, :without_ai]]
      field :position, :integer, allow_nil?: false, constraints: [min: 0]
      field :text, :string, allow_nil?: false
    end
  end

  defmodule LinePrompt do
    @moduledoc false
    use Ash.TypedStruct

    typed_struct do
      field :position, :integer, allow_nil?: false, constraints: [min: 0]
      field :template, :string, allow_nil?: false
    end
  end

  defmodule ChangeDescriptions do
    @moduledoc false
    use Ash.TypedStruct

    typed_struct do
      field :a, :string, allow_nil?: false
      field :b, :string, allow_nil?: false
    end
  end

  defmodule Modification do
    @moduledoc false
    use Ash.TypedStruct

    typed_struct do
      field :base, :string, allow_nil?: false
      field :change_descriptions, ChangeDescriptions, allow_nil?: false
    end
  end

  defmodule Llm do
    @moduledoc false
    use Ash.TypedStruct

    typed_struct do
      field :system_preamble, :string, allow_nil?: false
      field :retry_suffix, :string, allow_nil?: false
      field :line_prompts, {:array, LinePrompt}, allow_nil?: false, constraints: [min_length: 1]
      field :modification, Modification, allow_nil?: false
    end
  end

  defmodule HaikuIntro do
    @moduledoc false
    use Ash.TypedStruct

    typed_struct do
      field :before, :string, allow_nil?: false
      field :after, :string, allow_nil?: false
    end
  end

  defmodule Questionnaire do
    @moduledoc false
    use Ash.TypedStruct

    typed_struct do
      field :scale, Scale, allow_nil?: false
      field :haiku_intro, HaikuIntro, allow_nil?: false
      field :items, {:array, LikertItem}, allow_nil?: false, constraints: [min_length: 1]
      field :open_questions, {:array, OpenQuestion}, allow_nil?: false
    end
  end

  defmodule StudyConfig do
    @moduledoc false
    use Ash.TypedStruct

    typed_struct do
      field :title, :string, allow_nil?: false
      field :intro, Intro, allow_nil?: false
      field :task_messages, {:array, TaskMessage}, allow_nil?: false
      field :syllable_targets, {:array, :integer}, allow_nil?: false, constraints: [min_length: 1]
      field :llm, Llm, allow_nil?: false
      field :questionnaire, Questionnaire, allow_nil?: false
      field :screens, Screens, allow_nil?: false
    end
  end
end
