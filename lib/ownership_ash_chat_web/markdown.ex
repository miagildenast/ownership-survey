defmodule OwnershipAshChatWeb.Markdown do
  @moduledoc """
  Renders configured study copy (Markdown authored by the study team in
  `priv/study/config.yml`) to safe HTML for HEEx templates.

  Returns a `{:safe, iodata}` tuple so it can be interpolated directly in HEEx
  (`{Markdown.to_html(text)}`) and rendered unescaped, without scattering `raw/1`
  through the templates. The source is trusted (a developer-authored config file),
  so no HTML sanitizer is applied.
  """

  @doc "Render Markdown to a `{:safe, html}` tuple. `nil`/blank → empty safe string."
  def to_html(nil), do: {:safe, ""}

  def to_html(markdown) when is_binary(markdown) do
    case String.trim(markdown) do
      "" -> {:safe, ""}
      _ -> {:safe, Earmark.as_html!(markdown, compact_output: true)}
    end
  end
end
