defmodule Assistant.Reply.Delivery do
  alias Assistant.Journal
  alias Assistant.Reply.Text

  def publish(nil, _event), do: :ok

  def publish(chat_id, event) do
    Phoenix.PubSub.broadcast(Assistant.PubSub, topic(chat_id), event)
  end

  def chats_changed(chat_id) do
    Phoenix.PubSub.broadcast(Assistant.PubSub, "assistant:chats", {:chats_changed, chat_id})
  end

  def publish_phase(%{chat_id: nil}), do: :ok

  def publish_phase(state) do
    publish(state.chat_id, {:slot, snapshot(state)})
  end

  def flush_now(%{dirty: true, turn_id: id} = state) when not is_nil(id) do
    text = Text.full_text(state)
    thinking = Text.full_thinking(state)
    Journal.write_partial(id, text, thinking)

    publish(state.chat_id, {
      :partial,
      %{id: id, content: text, thinking: thinking, status: "partial"}
    })

    %{state | dirty: false}
  end

  def flush_now(state), do: state

  def usage_commit(%{turn_id: nil} = state), do: %{state | last_usage: {0, 0}}

  def usage_commit(%{last_usage: {prompt, eval}} = state) when prompt > 0 or eval > 0 do
    case Journal.add_usage(state.turn_id, prompt, eval) do
      {:ok, chat_id, spend} -> publish(chat_id, {:spend, %{chat_id: chat_id, token_spend: spend}})
      :ok -> :ok
    end

    %{state | last_usage: {0, 0}}
  end

  def usage_commit(state), do: state

  def schedule_flush(state) do
    cancel_timer(state)
    timer = Process.send_after(self(), :flush, flush_interval())
    %{state | timer: timer}
  end

  def cancel_timer(state) do
    if is_reference(state.timer), do: Process.cancel_timer(state.timer)
    %{state | timer: nil}
  end

  def snapshot(state) do
    %{
      phase: state.phase,
      chat_id: state.chat_id,
      turn_id: state.turn_id,
      attempts: state.attempts
    }
  end

  defp topic(chat_id), do: "assistant:chat:" <> to_string(chat_id)

  defp flush_interval, do: Application.get_env(:assistant, :flush_interval_ms, 40)
end
