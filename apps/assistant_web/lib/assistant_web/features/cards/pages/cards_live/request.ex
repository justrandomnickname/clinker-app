defmodule AssistantWeb.Features.Cards.Pages.CardsLive.Request do
  import Phoenix.Component, only: [assign: 2, assign: 3]

  alias AssistantWeb.Features.Cards.Pages.CardsLive.{Log, Screen}
  alias Phoenix.LiveView

  require Phoenix.LiveView

  def boot(socket) do
    assign(socket,
      tags: [],
      tag_draft: "",
      slug: nil,
      list_token: 0,
      card_token: 0,
      cards: Phoenix.LiveView.AsyncResult.loading(),
      card: nil
    )
  end

  def open(socket, params) do
    slug = params["slug"]
    slug = if is_binary(slug) and slug != "", do: slug, else: nil
    socket = assign(socket, :slug, slug)
    socket = reload(socket)

    if slug do
      load_card(socket, slug)
    else
      assign(socket, :card, nil)
    end
  end

  def filter(socket, text) do
    socket
    |> assign(:tag_draft, text)
    |> assign(:tags, Log.tags(text))
    |> reload()
  end

  def reload(socket) do
    token = System.unique_integer([:positive])
    tags = socket.assigns.tags

    socket
    |> assign(:list_token, token)
    |> LiveView.start_async(:cards, fn -> {token, Cards.list(tags)} end)
  end

  def loaded(socket, :cards, {token, result}) do
    if socket.assigns.list_token == token do
      Screen.put_cards(socket, result)
    else
      socket
    end
  end

  def loaded(socket, :card, {token, result}) do
    if socket.assigns.card_token == token do
      Screen.put_card(socket, result)
    else
      socket
    end
  end

  def loaded(socket, _name, _value), do: socket

  def failed(socket, :cards, reason) do
    Screen.put_cards(socket, {:error, reason})
  end

  def failed(socket, :card, reason) do
    Screen.put_card(socket, {:error, reason})
  end

  def failed(socket, _name, _reason), do: socket

  defp load_card(socket, slug) do
    token = System.unique_integer([:positive])

    socket
    |> assign(:card_token, token)
    |> assign(:card, Phoenix.LiveView.AsyncResult.loading())
    |> LiveView.start_async(:card, fn -> {token, Cards.get(slug)} end)
  end
end
