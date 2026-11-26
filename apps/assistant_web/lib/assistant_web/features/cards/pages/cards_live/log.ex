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

  def linked(body) when is_binary(body), do: link_slugs(body)
  def linked(_), do: ""

  defp link_slugs(body) do
    Regex.replace(~r/\[\[([a-z0-9-]{1,64})\]\]/, body, fn _, slug ->
      "[#{slug}](/cards/#{slug})"
    end)
  end
end
