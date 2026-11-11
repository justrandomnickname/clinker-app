defmodule AssistantWeb.Features.Chat.Components.ChatInput do
  use Phoenix.Component

  alias AssistantWeb.Shared.Components.Button
  alias Phoenix.LiveView.AsyncResult

  embed_templates("chat_input*")

  attr(:draft, :string, required: true)
  attr(:phase, AsyncResult, required: true)
  attr(:reason, :string, default: nil)
  attr(:meter, AsyncResult, required: true)
  def chat_input(assigns)

  def caption(%AsyncResult{result: %{used: used, limit: limit, balance: balance}})
      when is_integer(used) and is_integer(limit) and limit > 0 do
    case money(balance) do
      nil -> "#{grouped(used)} / #{grouped(limit)}"
      text -> "#{grouped(used)} / #{grouped(limit)} · #{text}"
    end
  end

  def caption(_meter), do: ""

  defp money(%{currency: "USD", cents: cents}) when is_integer(cents) do
    sign = if cents < 0, do: "-", else: ""
    cents = abs(cents)
    dollars = div(cents, 100)
    fraction = cents |> rem(100) |> Integer.to_string() |> String.pad_leading(2, "0")
    sign <> "$" <> Integer.to_string(dollars) <> "." <> fraction
  end

  defp money(_balance), do: nil

  defp grouped(number) do
    number
    |> Integer.to_string()
    |> String.replace(~r/\B(?=(\d{3})+(?!\d))/, " ")
  end
end
