defmodule AssistantWeb.Features.Context.Pages.ContextLive.Event do
  import Phoenix.Component, only: [assign: 2]

  alias AssistantWeb.Shared.ContextSlug
  alias Phoenix.LiveView

  def draft(socket, text) do
    assign(socket, draft: text, reason: nil)
  end

  def enter(socket, text) do
    case ContextSlug.canonical(text) do
      {:ok, slug} -> LiveView.push_navigate(socket, to: "/chat/" <> slug)
      :reserved -> assign(socket, reason: "Такой контекст нельзя")
      :error -> assign(socket, reason: "Введите контекст")
    end
  end
end
