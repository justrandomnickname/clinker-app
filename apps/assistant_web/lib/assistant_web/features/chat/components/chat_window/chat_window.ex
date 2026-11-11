defmodule AssistantWeb.Features.Chat.Components.ChatWindow do
  use Phoenix.Component

  alias AssistantWeb.Features.Chat.Components.ChatWindow.Markdown
  alias Phoenix.LiveView.AsyncResult

  embed_templates("chat_window*")

  attr(:messages, AsyncResult, required: true)
  def chat_window(assigns)
end
