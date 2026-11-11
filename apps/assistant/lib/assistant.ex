defmodule Assistant do
  def submit(chat_id, text) when is_binary(text) do
    if String.trim(text) == "" do
      {:error, :empty}
    else
      call_turn(chat_id, {:submit, text})
    end
  end

  def submit(_chat_id, _text), do: {:error, :empty}

  def create_chat(context \\ "misc") do
    case Assistant.Journal.create_chat(context) do
      {:ok, chat} = ok ->
        Assistant.Reply.Delivery.chats_changed(chat.id)
        ok

      other ->
        other
    end
  end

  def list_chats(context \\ :all), do: Assistant.Journal.list_chats(context)
  def messages(chat_id), do: Assistant.Journal.messages(chat_id)
  def spend(chat_id), do: Assistant.Journal.spend(chat_id)
  def spend_total, do: Assistant.Journal.spend_total()

  def meter(chat_id) do
    case Assistant.Journal.provider_name() do
      "gemini" ->
        %{
          used: Assistant.Journal.context_used(chat_id),
          limit: AssistantInference.Gemini.context_limit(),
          balance: AssistantInference.Gemini.balance()
        }

      _ ->
        %{used: nil, limit: nil, balance: nil}
    end
  end

  def phase(chat_id) do
    case Assistant.Reply.whereis(chat_id) do
      nil ->
        :idle

      pid ->
        try do
          GenServer.call(pid, :phase)
        catch
          :exit, {:noproc, _} -> :idle
        end
    end
  end

  def complete(prompt), do: Assistant.Reply.complete(prompt)

  def select_provider(name), do: Assistant.Journal.select_provider(name)
  def put_key(key), do: AssistantInference.Gemini.put_key(key)

  def provider do
    name = Assistant.Journal.provider_name()

    %{
      name: name,
      key_set: AssistantInference.Gemini.key_set?(),
      ready:
        name == "gemini" and
          AssistantInference.Gemini.ready?(AssistantInference.Gemini.model())
    }
  end

  defp call_turn(chat_id, message, attempt \\ 0) do
    try do
      GenServer.call(Assistant.Reply.ensure(chat_id), message)
    catch
      :exit, {:noproc, _} when attempt < 1 -> call_turn(chat_id, message, attempt + 1)
    end
  end
end
