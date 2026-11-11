defmodule AssistantWeb.Features.Context.Pages.ContextLive do
  use Phoenix.LiveView

  alias AssistantWeb.Features.Context.Pages.ContextLive.Event

  def mount(_params, _session, socket) do
    {:ok, assign(socket, draft: "", reason: nil)}
  end

  def handle_event("draft", %{"text" => text}, socket) do
    {:noreply, Event.draft(socket, text)}
  end

  def handle_event("enter", %{"text" => text}, socket) do
    {:noreply, Event.enter(socket, text)}
  end
end
