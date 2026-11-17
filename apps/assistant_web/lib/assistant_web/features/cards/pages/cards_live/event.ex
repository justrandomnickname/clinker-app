defmodule AssistantWeb.Features.Cards.Pages.CardsLive.Event do
  alias AssistantWeb.Features.Cards.Pages.CardsLive.Request

  def filter(socket, text) when is_binary(text), do: Request.filter(socket, text)
  def filter(socket, _text), do: socket
end
