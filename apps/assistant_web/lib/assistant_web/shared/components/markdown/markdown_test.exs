defmodule AssistantWeb.Shared.Components.MarkdownTest do
  use ExUnit.Case, async: true

  alias AssistantWeb.Shared.Components.Markdown

  test "renders markdown and drops raw html" do
    html =
      "Привет, **жирный**\n\n<script>alert(1)</script>\n\n[ссылка](javascript:alert(1))"
      |> Markdown.html()
      |> Phoenix.HTML.safe_to_string()

    assert html =~ "<strong>жирный</strong>"
    refute html =~ "<script>"
    refute html =~ "javascript:"
  end
end
