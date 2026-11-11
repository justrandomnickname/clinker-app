defmodule AssistantWeb.Features.Chat.Components.ChatWindow.Markdown do
  def render(markdown) when is_binary(markdown) do
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
