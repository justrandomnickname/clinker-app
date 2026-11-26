defmodule AssistantWeb.Features.Chat.Components.ChatMenu do
  use Phoenix.Component

  alias AssistantWeb.Shared.Components.CircleButton
  alias Phoenix.LiveView.AsyncResult

  embed_templates("chat_menu*")

  attr(:chats, AsyncResult, required: true)
  attr(:open, :boolean, required: true)

  def chat_menu(assigns)
end
