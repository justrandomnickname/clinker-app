defmodule AssistantWeb.Features.Chat.Pages.ChatLive.Log do
  def turn(messages, user, assistant) do
    messages
    |> upsert(user)
    |> upsert(assistant)
  end

  def merge(loaded, nil), do: loaded

  def merge(loaded, live) do
    live_by_id = Map.new(live, &{&1.id, &1})
    known = MapSet.new(loaded, & &1.id)

    merged =
      Enum.map(loaded, fn message ->
        Map.get(live_by_id, message.id, message)
      end)

    merged ++ Enum.filter(live, &(&1.id not in known))
  end

  def partial(messages, %{id: id, content: content, status: status}) do
    Enum.map(messages, fn message ->
      if message.id == id do
        %{message | content: content, status: status}
      else
        message
      end
    end)
  end

  defp upsert(messages, incoming) do
    if Enum.any?(messages, &(&1.id == incoming.id)) do
      Enum.map(messages, fn message ->
        if message.id == incoming.id, do: incoming, else: message
      end)
    else
      messages ++ [incoming]
    end
  end
end
