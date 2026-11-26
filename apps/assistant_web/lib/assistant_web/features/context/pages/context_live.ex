defmodule AssistantWeb.Features.Context.Pages.ContextLive do
  use Phoenix.LiveView

  alias AssistantWeb.Features.Context.Pages.ContextLive.Event

  def mount(_params, _session, socket) do
    {:ok, assign(socket, draft: "", reason: nil, build: build_number())}
  end

  defp build_number do
    case System.get_env("HEROKU_RELEASE_VERSION") do
      version when is_binary(version) and version != "" -> version
      _ -> "dev"
    end
  end

  def handle_event("draft", %{"text" => text}, socket) do
    {:noreply, Event.draft(socket, text)}
  end

  def handle_event("enter", %{"text" => text}, socket) do
    {:noreply, Event.enter(socket, text)}
  end
end
