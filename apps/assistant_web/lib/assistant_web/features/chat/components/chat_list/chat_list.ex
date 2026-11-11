defmodule AssistantWeb.Features.Chat.Components.ChatList do
  use Phoenix.Component

  alias Phoenix.LiveView.AsyncResult

  embed_templates("chat_list*")

  attr(:chats, AsyncResult, required: true)
  attr(:current_id, :integer, default: nil)
  attr(:context, :any, required: true)
  def chat_list(assigns)

  def label(:all), do: "все"
  def label(context) when is_binary(context), do: context
  def label(_context), do: ""
end
