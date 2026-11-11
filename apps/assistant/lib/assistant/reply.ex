defmodule Assistant.Reply do
  use GenServer

  alias Assistant.Reply.Decision

  def child_spec(chat_id) when is_integer(chat_id) do
    %{
      id: {:chat, chat_id},
      start: {__MODULE__, :start_link, [chat_id]},
      restart: :temporary
    }
  end

  def child_spec(:manual) do
    %{
      id: {:manual, make_ref()},
      start: {__MODULE__, :start_link, [:manual]},
      restart: :temporary
    }
  end

  def start_link(chat_id) when is_integer(chat_id) do
    GenServer.start_link(__MODULE__, chat_id, name: via(chat_id))
  end

  def start_link(:manual) do
    GenServer.start_link(__MODULE__, :manual)
  end

  def via(chat_id), do: {:via, Registry, {Assistant.Reply.Registry, chat_id}}

  def whereis(chat_id) do
    case Registry.lookup(Assistant.Reply.Registry, chat_id) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end

  def ensure(chat_id) do
    case DynamicSupervisor.start_child(Assistant.Reply.Supervisor, child_spec(chat_id)) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
  end

  def complete(prompt) do
    if blank?(prompt) do
      {:error, :empty}
    else
      {:ok, pid} = DynamicSupervisor.start_child(Assistant.Reply.Supervisor, child_spec(:manual))
      GenServer.call(pid, {:manual, prompt}, :infinity)
    end
  end

  def reset_all do
    Assistant.Reply.Supervisor
    |> DynamicSupervisor.which_children()
    |> Enum.each(fn
      {_, pid, _, _} when is_pid(pid) ->
        DynamicSupervisor.terminate_child(Assistant.Reply.Supervisor, pid)

      _ ->
        :ok
    end)
  end

  def idle(chat_id) do
    %{
      phase: :idle,
      chat_id: chat_id,
      turn_id: nil,
      task: nil,
      ref: nil,
      attempts: 0,
      deadline: nil,
      base_text: "",
      base_thinking: "",
      new_text: "",
      new_thinking: "",
      dirty: false,
      timer: nil,
      manual: nil,
      last_usage: {0, 0}
    }
  end

  @impl true
  def init(arg) do
    Process.flag(:trap_exit, true)
    chat_id = if arg == :manual, do: nil, else: arg
    {:ok, idle(chat_id)}
  end

  @impl true
  def handle_call({:submit, text}, _from, state) do
    case Decision.submit(state, text) do
      {:ok, turn_id, state} -> finish_call({:ok, turn_id}, state)
      {:error, reason, state} -> finish_call({:error, reason}, state)
    end
  end

  def handle_call({:manual, prompt}, from, state) do
    case Decision.manual(state, prompt, from) do
      {:ok, state} -> {:noreply, state}
      {:error, reason, state} -> finish_call({:error, reason}, state)
    end
  end

  def handle_call(:phase, _from, state) do
    {:reply, state.phase, state}
  end

  @impl true
  def handle_info({:inference_chunk, ref, event}, %{ref: ref} = state) when not is_nil(ref) do
    continue(Decision.chunk(state, event))
  end

  def handle_info({:inference_chunk, _ref, _event}, state), do: continue(state)

  def handle_info({:inference_result, ref, result}, %{ref: ref} = state) when not is_nil(ref) do
    continue(Decision.result(state, result))
  end

  def handle_info({:inference_result, _ref, _result}, state), do: continue(state)

  def handle_info({:DOWN, _mref, :process, pid, reason}, %{task: pid} = state)
      when reason != :normal do
    continue(Decision.crashed(state))
  end

  def handle_info({:DOWN, _mref, :process, _pid, _reason}, state), do: continue(state)

  def handle_info(:flush, state), do: continue(Decision.flush(state))

  def handle_info(_message, state), do: continue(state)

  @impl true
  def terminate(_reason, %{phase: :idle}), do: :ok

  def terminate(_reason, state) do
    Decision.interrupt(state)
    :ok
  end

  defp finish_call(reply, %{phase: :idle} = state), do: {:stop, :normal, reply, state}
  defp finish_call(reply, state), do: {:reply, reply, state}

  defp continue(%{phase: :idle} = state), do: {:stop, :normal, state}
  defp continue(state), do: {:noreply, state}

  defp blank?(text), do: not is_binary(text) or String.trim(text) == ""
end
