defmodule Assistant.Reply.Decision do
  alias Assistant.Journal
  alias Assistant.Reply.{Delivery, Request, Text}

  @turn_ms 15 * 60 * 1000
  @max_failures 3

  def submit(state, text) do
    cond do
      blank?(text) ->
        {:error, :empty, state}

      state.phase != :idle ->
        {:error, :busy, state}

      true ->
        case prepare() do
          :ok ->
            Journal.interrupt_open_partials(state.chat_id)

            case Journal.start_turn(state.chat_id, text) do
              {:ok, %{turn_id: turn_id, user: user, assistant: assistant}} ->
                Delivery.publish(state.chat_id, {:turn, %{user: user, assistant: assistant}})
                Delivery.chats_changed(state.chat_id)
                state = %{state | turn_id: turn_id, manual: nil, deadline: nil}
                {:ok, turn_id, begin_attempt(state, :generate, 0)}

              {:error, reason} ->
                {:error, reason, state}
            end

          {:error, reason} ->
            {:error, reason, state}
        end
    end
  end

  def manual(state, prompt, from) do
    cond do
      blank?(prompt) ->
        {:error, :empty, state}

      state.phase != :idle ->
        {:error, :busy, state}

      true ->
        case prepare() do
          :ok ->
            state = %{
              state
              | manual: %{from: from, prompt: String.trim(prompt)},
                turn_id: nil,
                deadline: nil,
                base_text: "",
                base_thinking: "",
                new_text: "",
                new_thinking: ""
            }

            {:ok, begin_attempt(state, :generate, 0)}

          {:error, reason} ->
            {:error, reason, state}
        end
    end
  end

  def chunk(state, {:text, chunk}) do
    %{state | new_text: state.new_text <> chunk, dirty: true}
  end

  def chunk(state, {:thinking, chunk}) do
    %{state | new_thinking: state.new_thinking <> chunk, dirty: true}
  end

  def chunk(state, {:usage, prompt, eval}) do
    %{state | last_usage: {prompt, eval}}
  end

  def result(state, {:ok, usage}), do: succeed(%{state | task: nil, last_usage: usage})
  def result(state, {:error, reason}), do: fail(%{state | task: nil}, reason)

  def crashed(state), do: fail(%{state | task: nil}, :crash)

  def flush(%{phase: :idle} = state), do: state

  def flush(state) do
    state
    |> Delivery.flush_now()
    |> Delivery.schedule_flush()
  end

  def interrupt(state) do
    if state.task, do: send(state.task, {:cancel, state.ref})
    finish_interrupted(state, :cancelled)
  end

  defp prepare do
    with {:ok, _} <- Journal.system_prompt() do
      if gemini_ready?(), do: :ok, else: {:error, :unavailable}
    end
  end

  defp gemini_ready? do
    Journal.provider_name() == "gemini" and
      AssistantInference.Gemini.ready?(AssistantInference.Gemini.model())
  end

  defp begin_attempt(state, phase, attempts) do
    state =
      if phase == :resume do
        %{
          state
          | base_text: Text.full_text(state),
            base_thinking: Text.full_thinking(state),
            new_text: "",
            new_thinking: "",
            dirty: false
        }
      else
        state
      end

    state = %{state | phase: phase, attempts: attempts}

    case Request.build(state) do
      :system_prompt -> finish_interrupted(state, :system_prompt)
      request -> start_task(state, request)
    end
  end

  defp start_task(state, request) do
    ref = make_ref()
    parent = self()
    deadline = state.deadline || System.monotonic_time(:millisecond) + @turn_ms

    {:ok, pid} =
      Task.Supervisor.start_child(Assistant.TaskSupervisor, fn ->
        Process.monitor(parent)

        result =
          AssistantInference.Gemini.stream(request, parent: parent, ref: ref, deadline: deadline)

        send(parent, {:inference_result, ref, result})
      end)

    Process.monitor(pid)

    state = %{state | ref: ref, task: pid, deadline: deadline}
    state = Delivery.schedule_flush(state)
    Delivery.publish_phase(state)
    state
  end

  defp succeed(state) do
    if state.new_text == "" and state.new_thinking == "" do
      fail(state, :empty_response)
    else
      state = state |> Map.put(:dirty, true) |> Delivery.flush_now() |> Delivery.usage_commit()
      text = Text.full_text(state)
      thinking = Text.full_thinking(state)

      if state.turn_id do
        Journal.finish(state.turn_id, "complete", text, thinking)

        Delivery.publish(state.chat_id, {
          :partial,
          %{id: state.turn_id, content: text, thinking: thinking, status: "complete"}
        })
      end

      reply_manual(state, {:ok, text})
      settle(state)
    end
  end

  defp fail(state, reason) do
    state = state |> Delivery.flush_now() |> Delivery.usage_commit()
    attempts = state.attempts + 1
    state = %{state | attempts: attempts}

    cond do
      reason in [:system_prompt, :cancelled] or attempts >= @max_failures or time_up?(state) ->
        finish_interrupted(state, reason)

      true ->
        begin_attempt(state, :resume, attempts)
    end
  end

  defp finish_interrupted(state, reason) do
    text = Text.full_text(state)
    thinking = Text.full_thinking(state)

    if state.turn_id do
      Journal.finish(state.turn_id, "interrupted", text, thinking)

      Delivery.publish(state.chat_id, {
        :partial,
        %{id: state.turn_id, content: text, thinking: thinking, status: "interrupted"}
      })

      Delivery.publish(state.chat_id, {:error, reason})
    end

    reply_manual(state, {:error, reason})
    settle(state)
  end

  defp settle(state) do
    state = Delivery.cancel_timer(state)
    state = Assistant.Reply.idle(state.chat_id)
    Delivery.publish_phase(state)
    state
  end

  defp reply_manual(%{manual: %{from: from}}, result), do: GenServer.reply(from, result)
  defp reply_manual(_, _), do: :ok

  defp time_up?(%{deadline: nil}), do: false
  defp time_up?(%{deadline: deadline}), do: System.monotonic_time(:millisecond) >= deadline

  defp blank?(text), do: not is_binary(text) or String.trim(text) == ""
end
