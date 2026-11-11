defmodule AssistantWeb.Features.Chat.Pages.ChatLive.Request do
  import Phoenix.Component, only: [assign: 3]

  alias AssistantWeb.Features.Chat.Pages.ChatLive.{Log, Screen}
  alias AssistantWeb.Shared.ContextSlug
  alias Phoenix.LiveView
  alias Phoenix.LiveView.AsyncResult

  require Phoenix.LiveView

  def boot(socket) do
    if LiveView.connected?(socket) do
      Phoenix.PubSub.subscribe(Assistant.PubSub, "assistant:chats")
    end

    Screen.reset(socket, chat_id: nil, chats: AsyncResult.loading(), context: nil)
  end

  def open_context(socket, nil), do: open_list(socket, :all)

  def open_context(socket, raw) when is_binary(raw) do
    case ContextSlug.canonical(raw) do
      {:ok, slug} when slug == raw -> open_list(socket, slug)
      {:ok, slug} -> LiveView.push_navigate(socket, to: "/chat/" <> slug)
      :reserved -> LiveView.push_navigate(socket, to: "/chat")
      :error -> LiveView.push_navigate(socket, to: "/")
    end
  end

  def reload(%{assigns: %{context: context}} = socket)
      when context == :all or is_binary(context) do
    LiveView.start_async(socket, :chats, fn -> load_chats(context) end)
  end

  def reload(socket), do: socket

  @spec loaded(map(), :chats | :messages | :phase | :meter, any()) :: map()
  def loaded(socket, :chats, chats) do
    socket = assign(socket, :chats, AsyncResult.ok(socket.assigns.chats, chats))
    current = socket.assigns.chat_id

    if Enum.any?(chats, &(&1.id == current)) do
      socket
    else
      Screen.open(socket, hd(chats).id)
    end
  end

  def loaded(%{assigns: %{chat_id: nil}} = socket, :messages, _loaded), do: socket

  def loaded(socket, :messages, loaded) do
    Screen.put_messages(socket, Log.merge(loaded, socket.assigns.messages.result))
  end

  def loaded(%{assigns: %{chat_id: nil}} = socket, :phase, _phase), do: socket

  def loaded(socket, :phase, phase), do: Screen.put_phase(socket, phase)

  def loaded(%{assigns: %{chat_id: nil}} = socket, :meter, _meter), do: socket

  def loaded(socket, :meter, meter) do
    assign(socket, :meter, AsyncResult.ok(socket.assigns.meter, meter))
  end

  def failed(%{assigns: %{chat_id: nil}} = socket, name, _reason)
      when name in [:messages, :phase, :meter], do: socket

  def failed(socket, :chats, reason) do
    assign(socket, :chats, AsyncResult.failed(socket.assigns.chats, {:exit, reason}))
  end

  def failed(socket, :messages, reason) do
    assign(socket, :messages, AsyncResult.failed(socket.assigns.messages, {:exit, reason}))
  end

  def failed(socket, :phase, _reason), do: Screen.put_phase(socket, :idle)

  def failed(socket, :meter, _reason) do
    assign(
      socket,
      :meter,
      AsyncResult.ok(socket.assigns.meter, %{used: nil, limit: nil, balance: nil})
    )
  end

  defp open_list(%{assigns: %{context: context}} = socket, context), do: socket

  defp open_list(socket, context) do
    socket
    |> assign(:context, context)
    |> Screen.reset(chat_id: nil, chats: AsyncResult.loading())
    |> reload()
  end

  defp load_chats(context) do
    case Assistant.list_chats(context) do
      [] ->
        {:ok, chat} = Assistant.create_chat(create_context(context))
        [chat]

      chats ->
        chats
    end
  end

  defp create_context(:all), do: "misc"
  defp create_context(slug) when is_binary(slug), do: slug
end
