defmodule AssistantWeb.Features.Cards.Pages.CardsLive do
  use Phoenix.LiveView
  use AssistantWeb.Shared.Page

  alias AssistantWeb.Features.Cards.Pages.CardsLive.{Event, Log, Request}

  def mount(_params, _session, socket) do
    {:ok, Request.boot(socket)}
  end

  def handle_params(params, _uri, socket) do
    {:noreply, Request.open(socket, params)}
  end

  def handle_event("filter", %{"tags" => text}, socket) do
    {:noreply, Event.filter(socket, text)}
  end
end
