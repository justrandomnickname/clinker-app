defmodule AssistantWeb.Features.Context.Pages.ContextLive do
  use Phoenix.LiveView

  alias AssistantWeb.Features.Context.Pages.ContextLive.Event

  @build (
    case System.get_env("SOURCE_VERSION") do
      sha when is_binary(sha) and byte_size(sha) >= 7 ->
        String.slice(sha, 0, 7)

      _ ->
        case System.cmd("git", ["rev-parse", "--short=7", "HEAD"], stderr_to_stdout: true) do
          {sha, 0} -> String.trim(sha)
          _ -> "dev"
        end
    end
  )

  def mount(_params, _session, socket) do
    {:ok, assign(socket, draft: "", reason: nil, build: @build)}
  end

  def handle_event("draft", %{"text" => text}, socket) do
    {:noreply, Event.draft(socket, text)}
  end

  def handle_event("enter", %{"text" => text}, socket) do
    {:noreply, Event.enter(socket, text)}
  end
end
