defmodule AssistantWeb.Features.Chat.Components.ChatWindow.MarkdownTest do
  use ExUnit.Case, async: true

  alias AssistantWeb.Features.Chat.Components.ChatWindow.Markdown

  test "renders markdown and drops raw html" do
    html =
      html("Привет, **жирный**\n\n<script>alert(1)</script>\n\n[ссылка](javascript:alert(1))")

    assert html =~ "<strong>жирный</strong>"
    refute html =~ "<script>"
    refute html =~ "javascript:"
  end

  defp html(markdown) do
    markdown
    |> Markdown.render()
    |> Phoenix.HTML.safe_to_string()
  end
end
