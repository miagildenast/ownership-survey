defmodule OwnershipAshChat.Study.Run.Validations.OpenEndedAnswers do
  @moduledoc """
  Validates the `open_answers` attribute against the configured open-ended questions.

  Open-ended questions are only asked on the **modification run** (`kind ==
  :modification`):

    * modification run — exactly the configured open-question keys must be present
      (no missing, no extra) and every value must be a non-blank string,
    * writing runs — `open_answers` must be empty (they carry no open answers).

  Validations cannot modify the changeset; this only accepts or rejects. It reads the
  record's `kind` (`Ash.Changeset.get_data/2`), so it runs on the changeset and the
  owning action sets `require_atomic? false` (mirrors `LikertAnswers`).
  """
  use Ash.Resource.Validation

  alias OwnershipAshChat.Study.Likert

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    answers = Ash.Changeset.get_attribute(changeset, :open_answers) || %{}

    case Ash.Changeset.get_data(changeset, :kind) do
      :modification -> validate_modification(answers)
      _other -> validate_empty(answers)
    end
  end

  defp validate_modification(answers) do
    with :ok <- validate_keys(answers) do
      validate_values(answers)
    end
  end

  defp validate_keys(answers) do
    expected = MapSet.new(Likert.open_string_keys())
    actual = answers |> Map.keys() |> Enum.map(&to_string/1) |> MapSet.new()

    if MapSet.equal?(expected, actual) do
      :ok
    else
      {:error,
       field: :open_answers,
       message:
         "must contain exactly the open questions: #{Enum.join(Likert.open_string_keys(), ", ")}"}
    end
  end

  defp validate_values(answers) do
    if Enum.all?(answers, fn {_key, value} -> is_binary(value) and String.trim(value) != "" end) do
      :ok
    else
      {:error, field: :open_answers, message: "every open answer must be a non-blank string"}
    end
  end

  defp validate_empty(answers) when map_size(answers) == 0, do: :ok

  defp validate_empty(_answers),
    do:
      {:error, field: :open_answers, message: "only the modification run may carry open answers"}
end
