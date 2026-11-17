defmodule AssistantWeb.Features.Cards.Pages.CardsLive.Screen do
  import Phoenix.Component, only: [assign: 3]

  alias Phoenix.LiveView.AsyncResult

  def deliver(socket, _message), do: socket

  def put_cards(socket, {:ok, cards}) do
    assign(socket, :cards, AsyncResult.ok(socket.assigns.cards, {:cards, cards}))
  end

  def put_cards(socket, {:error, :unavailable}) do
    assign(socket, :cards, AsyncResult.ok(socket.assigns.cards, :unavailable))
  end

  def put_cards(socket, {:error, _reason}) do
    assign(socket, :cards, AsyncResult.failed(socket.assigns.cards, :error))
  end

  def put_card(%{assigns: %{slug: nil}} = socket, _result), do: socket

  def put_card(socket, {:ok, card}) do
    if socket.assigns.slug == card.slug do
      assign(socket, :card, AsyncResult.ok(socket.assigns.card, card))
    else
      socket
    end
  end

  def put_card(socket, {:error, :missing}) do
    assign(socket, :card, AsyncResult.failed(socket.assigns.card, :missing))
  end

  def put_card(socket, {:error, :unavailable}) do
    assign(socket, :card, AsyncResult.failed(socket.assigns.card, :unavailable))
  end

  def put_card(socket, {:error, _reason}) do
    assign(socket, :card, AsyncResult.failed(socket.assigns.card, :error))
  end
end
