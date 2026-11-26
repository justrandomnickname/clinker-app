defmodule AssistantWeb.Features.Chat.Pages.ChatLive do
  use Phoenix.LiveView
  use AssistantWeb.Shared.Page

  alias AssistantWeb.Features.Chat.Components.{
    ChatInput,
    ChatList,
    ChatMenu,
    ChatWindow,
    ContextModal
  }

  alias AssistantWeb.Shared.Components.CircleButton
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

  def handle_event("delete_chat", %{"id" => id}, socket) do
    {:noreply, Event.delete_chat(socket, String.to_integer(id))}
  end

  def handle_event("open_menu", _params, socket) do
    {:noreply, Event.open_menu(socket)}
  end

  def handle_event("close_menu", _params, socket) do
    {:noreply, Event.close_menu(socket)}
  end

  def handle_event("open_context_modal", _params, socket) do
    {:noreply, Event.open_context_modal(socket)}
  end

  def handle_event("close_context_modal", _params, socket) do
    {:noreply, Event.close_context_modal(socket)}
  end

  def handle_event("context_draft", %{"text" => text}, socket) do
    {:noreply, Event.context_draft(socket, text)}
  end

  def handle_event("enter_context", %{"text" => text}, socket) do
    {:noreply, Event.enter_context(socket, text)}
  end
end
