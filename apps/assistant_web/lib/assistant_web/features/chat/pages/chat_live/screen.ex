defmodule AssistantWeb.Features.Chat.Pages.ChatLive.Screen do
  import Phoenix.Component, only: [assign: 2, assign: 3]

  alias AssistantWeb.Features.Chat.Pages.ChatLive.{Log, Request}
  alias Phoenix.LiveView
  alias Phoenix.LiveView.AsyncResult

  require Phoenix.LiveView

  def open(socket, chat_id) do
    unsubscribe(socket, socket.assigns.chat_id)
    subscribe(socket, chat_id)

    socket
    |> reset(chat_id: chat_id)
    |> LiveView.start_async(:messages, fn -> Assistant.messages(chat_id) end)
    |> LiveView.start_async(:phase, fn -> Assistant.phase(chat_id) end)
    |> LiveView.start_async(:meter, fn -> Assistant.meter(chat_id) end)
  end

  def reset(socket, assigns) do
    assign(
      socket,
      Keyword.merge(
        [
          draft: "",
          reason: nil,
          messages: AsyncResult.loading(),
          phase: AsyncResult.loading(),
          meter: AsyncResult.loading()
        ],
        assigns
      )
    )
  end

  def put_messages(socket, messages) do
    assign(socket, :messages, AsyncResult.ok(socket.assigns.messages, messages))
  end

  def put_phase(%{assigns: %{phase: %AsyncResult{ok?: true}}} = socket, _phase), do: socket

  def put_phase(socket, phase) do
    assign(socket, :phase, AsyncResult.ok(socket.assigns.phase, phase))
  end

  def reason(:empty), do: "Пустое сообщение"
  def reason(:chat), do: "Не удалось создать чат"
  def reason(:busy), do: "Ответ ещё пишется"
  def reason(:wrong_chat), do: "Это не текущий чат"
  def reason(:unavailable), do: "Модель недоступна"
  def reason(:system_prompt), do: "Системный промпт не читается"
  def reason(:empty_response), do: "Пустой ответ"
  def reason(:timeout), do: "Ответ оборвался"
  def reason(_reason), do: "Не получилось отправить"

  def deliver(socket, {:chats_changed, _chat_id}), do: Request.reload(socket)

  def deliver(socket, {:slot, %{chat_id: chat_id} = snapshot})
      when chat_id == socket.assigns.chat_id do
    assign(socket, :phase, AsyncResult.ok(socket.assigns.phase, snapshot.phase))
  end

  def deliver(socket, {:turn, %{user: user, assistant: assistant}})
      when user.chat_id == socket.assigns.chat_id do
    put_messages(socket, Log.turn(message_list(socket), user, assistant))
  end

  def deliver(socket, {:partial, partial}) do
    current = message_list(socket)
    messages = Log.partial(current, partial)

    if messages == current and is_nil(socket.assigns.messages.result) do
      socket
    else
      put_messages(socket, messages)
    end
  end

  def deliver(socket, {:error, reason}) do
    assign(socket, reason: reason(reason))
  end

  def deliver(socket, {:spend, %{chat_id: chat_id}}) when chat_id == socket.assigns.chat_id do
    LiveView.start_async(socket, :meter, fn -> Assistant.meter(chat_id) end)
  end

  def deliver(socket, _message), do: socket

  defp subscribe(socket, chat_id) do
    if LiveView.connected?(socket) do
      Phoenix.PubSub.subscribe(Assistant.PubSub, chat_topic(chat_id))
    end
  end

  defp unsubscribe(_socket, nil), do: :ok

  defp unsubscribe(socket, chat_id) do
    if LiveView.connected?(socket) do
      Phoenix.PubSub.unsubscribe(Assistant.PubSub, chat_topic(chat_id))
    end
  end

  defp chat_topic(chat_id), do: "assistant:chat:" <> to_string(chat_id)

  defp message_list(socket), do: socket.assigns.messages.result || []
end
