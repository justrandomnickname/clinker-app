defmodule AssistantWeb.Features.Chat.Pages.ChatLive.Event do
  import Phoenix.Component, only: [assign: 2]

  alias AssistantWeb.Features.Chat.Pages.ChatLive.Screen
  alias AssistantWeb.Shared.ContextSlug
  alias Phoenix.LiveView

  def draft(socket, text) do
    assign(socket, draft: text, reason: nil)
  end

  def send(socket, text) do
    case Assistant.submit(socket.assigns.chat_id, text) do
      {:ok, _turn_id} -> assign(socket, draft: "", reason: nil)
      {:error, reason} -> assign(socket, reason: Screen.reason(reason))
    end
  end

  def select(socket, chat_id) when chat_id == socket.assigns.chat_id,
    do: Screen.close_menu(socket)

  def select(socket, chat_id), do: Screen.open(socket, chat_id)

  def new_chat(socket) do
    case Assistant.create_chat(create_context(socket.assigns.context)) do
      {:ok, chat} -> Screen.open(socket, chat.id)
      {:error, _reason} -> assign(socket, reason: Screen.reason(:chat))
    end
  end

  def open_menu(socket), do: Screen.open_menu(socket)

  def close_menu(socket), do: Screen.close_menu(socket)

  def open_context_modal(socket), do: Screen.open_context_modal(socket)

  def close_context_modal(socket), do: Screen.close_context_modal(socket)

  def context_draft(socket, text) do
    assign(socket, context_draft: text, context_reason: nil)
  end

  def enter_context(socket, text) do
    case ContextSlug.canonical(text) do
      {:ok, slug} -> LiveView.push_navigate(socket, to: "/chat/" <> slug)
      :reserved -> assign(socket, context_reason: "Такой контекст нельзя")
      :error -> assign(socket, context_reason: "Введите контекст")
    end
  end

  def delete_chat(socket, chat_id) do
    case Assistant.delete_chat(chat_id) do
      :ok -> socket
      {:error, _reason} -> assign(socket, reason: Screen.reason(:delete))
    end
  end

  defp create_context(:all), do: "misc"
  defp create_context(slug) when is_binary(slug), do: slug
end
