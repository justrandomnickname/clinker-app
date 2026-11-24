defmodule AssistantWeb.Features.Chat.Components.ChatList do
  use Phoenix.Component

  alias AssistantWeb.Shared.Components.Button
  alias Phoenix.LiveView.AsyncResult

  embed_templates("chat_list*")

  attr(:chats, AsyncResult, required: true)
  def chat_list(assigns)
end
