defmodule AssistantWeb.Shared.Components.Markdown do
  use Phoenix.Component

  embed_templates("markdown*")

  attr :source, :string, required: true
  attr :class, :any, default: nil

  def markdown(assigns)

  def html(markdown) when is_binary(markdown) do
    markdown
    |> MDEx.to_html!(
      extension: [
        strikethrough: true,
        table: true,
        autolink: true,
        tasklist: true
      ],
      sanitize: MDEx.Document.default_sanitize_options(),
      syntax_highlight: nil,
      auto_close: true
    )
    |> Phoenix.HTML.raw()
  end
end
