defmodule AssistantWeb.Features.Chat.Components.ChatInput do
  use Phoenix.Component

  alias AssistantWeb.Shared.Components.{CircleButton, Input}
  alias Phoenix.LiveView.AsyncResult

  embed_templates("chat_input*")

  attr(:draft, :string, required: true)
  attr(:phase, AsyncResult, required: true)
  attr(:meter, AsyncResult, required: true)
  def chat_input(assigns)

  def caption(%AsyncResult{result: %{used: used, limit: limit}})
      when is_integer(used) and is_integer(limit) and limit > 0 do
    "#{compact(used)} / #{compact(limit)}"
  end

  def caption(_meter), do: "0 / 0"

  defp compact(number) when number >= 1_000_000, do: scaled(number, 1_000_000) <> "kk"
  defp compact(number) when number >= 1_000, do: scaled(number, 1_000) <> "k"
  defp compact(number), do: Integer.to_string(number)

  defp scaled(number, unit) do
    tenths = div(number * 10 + div(unit, 2), unit)
    whole = div(tenths, 10)
    fraction = rem(tenths, 10)

    if fraction == 0 do
      Integer.to_string(whole)
    else
      "#{whole}.#{fraction}"
    end
  end
end
