defmodule AssistantWeb.Features.Cards.Pages.CardsLive.Log do
  @token ~r/^[a-z0-9-]{1,64}$/

  def tags(text) when is_binary(text) do
    text
    |> String.downcase()
    |> String.split(~r/[\s,]+/, trim: true)
    |> Enum.filter(&(&1 =~ @token))
    |> Enum.uniq()
    |> Enum.take(32)
  end

  def tags(_), do: []

  def html(body) when is_binary(body) do
    body
    |> link_slugs()
    |> MDEx.to_html!(
      extension: [strikethrough: true, table: true, autolink: true, tasklist: true],
      sanitize: MDEx.Document.default_sanitize_options(),
      syntax_highlight: nil,
      auto_close: true
    )
    |> Phoenix.HTML.raw()
  end

  def html(_), do: Phoenix.HTML.raw("")

  defp link_slugs(body) do
    Regex.replace(~r/\[\[([a-z0-9-]{1,64})\]\]/, body, fn _, slug ->
      "[#{slug}](/cards/#{slug})"
    end)
  end
end
