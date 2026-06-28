defmodule OwnershipAshChat.Study.Run.Validations.LikertAnswers do
  @moduledoc """
  Validates the `likert` attribute against the `Likert` questionnaire definition:

    * exactly the expected item keys are present — no missing, no extra keys,
    * every value is an integer within the rating scale (`Likert.scale/0`).

  Validations cannot modify the changeset; this only accepts or rejects. The
  questionnaire map is small and the rules are not expressible as DB expressions,
  so this runs on the changeset (the owning action sets `require_atomic? false`).
  """
  use Ash.Resource.Validation

  alias OwnershipAshChat.Study.Likert

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    answers = Ash.Changeset.get_attribute(changeset, :likert) || %{}

    with :ok <- validate_keys(answers),
         :ok <- validate_values(answers) do
      :ok
    end
  end

  defp validate_keys(answers) do
    expected = MapSet.new(Likert.string_keys())
    actual = answers |> Map.keys() |> Enum.map(&to_string/1) |> MapSet.new()

    if MapSet.equal?(expected, actual) do
      :ok
    else
      {:error,
       field: :likert,
       message:
         "must contain exactly the questionnaire items: #{Enum.join(Likert.string_keys(), ", ")}"}
    end
  end

  defp validate_values(answers) do
    if Enum.all?(answers, fn {_key, value} -> value in Likert.scale() end) do
      :ok
    else
      lo = Enum.min(Likert.scale())
      hi = Enum.max(Likert.scale())

      {:error, field: :likert, message: "every answer must be an integer between #{lo} and #{hi}"}
    end
  end
end
