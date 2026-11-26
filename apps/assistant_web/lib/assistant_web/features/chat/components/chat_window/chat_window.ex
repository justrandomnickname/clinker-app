defmodule AssistantWeb.Features.Chat.Components.ChatWindow do
  use Phoenix.Component

  alias AssistantWeb.Shared.Components.Markdown
  alias Phoenix.LiveView.AsyncResult

  embed_templates("chat_window*")

  attr(:messages, AsyncResult, required: true)
  def chat_window(assigns)
end
