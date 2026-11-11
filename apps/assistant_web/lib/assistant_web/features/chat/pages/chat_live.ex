defmodule AssistantWeb.Features.Chat.Pages.ChatLive do
  use Phoenix.LiveView
  use AssistantWeb.Shared.Page

  alias AssistantWeb.Features.Chat.Components.{ChatInput, ChatList, ChatWindow}
  alias AssistantWeb.Features.Chat.Pages.ChatLive.{Event, Request}

  def mount(_params, _session, socket) do
    {:ok, Request.boot(socket)}
  end

  def handle_params(params, _uri, socket) do
    {:noreply, Request.open_context(socket, params["context"])}
  end

  def handle_event("draft", %{"text" => text}, socket) do
    {:noreply, Event.draft(socket, text)}
  end

  def handle_event("send", %{"text" => text}, socket) do
    {:noreply, Event.send(socket, text)}
  end

  def handle_event("select_chat", %{"id" => id}, socket) do
    {:noreply, Event.select(socket, String.to_integer(id))}
  end

  def handle_event("new_chat", _params, socket) do
    {:noreply, Event.new_chat(socket)}
  end
end
