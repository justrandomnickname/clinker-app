defmodule AssistantWeb.Features.Chat.Pages.ChatLive.Event do
  import Phoenix.Component, only: [assign: 2]

  alias AssistantWeb.Features.Chat.Pages.ChatLive.Screen

  def draft(socket, text) do
    assign(socket, draft: text, reason: nil)
  end

  def send(socket, text) do
    case Assistant.submit(socket.assigns.chat_id, text) do
      {:ok, _turn_id} -> assign(socket, draft: "", reason: nil)
      {:error, reason} -> assign(socket, reason: Screen.reason(reason))
    end
  end

  def select(socket, chat_id) when chat_id == socket.assigns.chat_id, do: socket
  def select(socket, chat_id), do: Screen.open(socket, chat_id)

  def new_chat(socket) do
    case Assistant.create_chat(create_context(socket.assigns.context)) do
      {:ok, chat} -> Screen.open(socket, chat.id)
      {:error, _reason} -> assign(socket, reason: Screen.reason(:chat))
    end
  end

  defp create_context(:all), do: "misc"
  defp create_context(slug) when is_binary(slug), do: slug
end
