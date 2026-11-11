defmodule Assistant.ReplyTest do
  use ExUnit.Case, async: false

  setup do
    Req.Test.set_req_test_to_shared()
    Assistant.Reply.reset_all()
    Assistant.Repo.delete_all(Assistant.Journal.Message)
    Assistant.Repo.delete_all(Assistant.Journal.Chat)
    :ok
  end

  test "a turn stores text, thinking and tokens, and does not send thinking back" do
    bodies = stub_sequence(fn n ->
      if n == 0 do
        {[
           %{"text" => "THOUGHT-MARKER", "thought" => true},
           %{"text" => "VISIBLE-MARKER"}
         ], %{"promptTokenCount" => 5, "candidatesTokenCount" => 2, "thoughtsTokenCount" => 3}}
      else
        {[%{"text" => "ещё"}], %{"promptTokenCount" => 7, "candidatesTokenCount" => 1, "thoughtsTokenCount" => 0}}
      end
    end)

    {:ok, chat} = Assistant.create_chat()
    Phoenix.PubSub.subscribe(Assistant.PubSub, "assistant:chat:#{chat.id}")
    assert {:ok, turn_id} = Assistant.submit(chat.id, "короткий вопрос")
    assert_receive {:slot, %{phase: :idle}}, 2_000

    [user, assistant] = Assistant.messages(chat.id)
    assert user.role == "user"
    assert user.status == "complete"
    assert assistant.id == turn_id
    assert assistant.content == "VISIBLE-MARKER"
    assert assistant.thinking == "THOUGHT-MARKER"
    assert assistant.status == "complete"
    assert assistant.prompt_tokens == 5
    assert assistant.eval_tokens == 5
    assert Assistant.spend(chat.id) == 10
    assert Assistant.spend_total() == 10
    assert hd(Assistant.list_chats()).title == "короткий вопрос"

    assert {:ok, _} = Assistant.submit(chat.id, "дальше")
    assert_receive {:slot, %{phase: :idle}}, 2_000

    [first, second] = Agent.get(bodies, & &1)
    assert first =~ "короткий вопрос"
    refute first =~ "THOUGHT-MARKER"
    assert second =~ "VISIBLE-MARKER"
    refute second =~ "THOUGHT-MARKER"
    refute second =~ "продолжай с места обрыва"
  end

  test "an empty reply is retried and both usages count" do
    stub_sequence(fn n ->
      if n == 0 do
        {[], %{"promptTokenCount" => 4, "candidatesTokenCount" => 0, "thoughtsTokenCount" => 0}}
      else
        {[%{"text" => "готово"}], %{"promptTokenCount" => 6, "candidatesTokenCount" => 1, "thoughtsTokenCount" => 2}}
      end
    end)

    {:ok, chat} = Assistant.create_chat()
    Phoenix.PubSub.subscribe(Assistant.PubSub, "assistant:chat:#{chat.id}")
    assert {:ok, turn_id} = Assistant.submit(chat.id, "вопрос")
    assert_receive {:slot, %{phase: :resume, attempts: 1, turn_id: ^turn_id}}, 2_000
    assert_receive {:slot, %{phase: :idle}}, 2_000

    message = Assistant.Journal.get_message(turn_id)
    assert message.status == "complete"
    assert message.content == "готово"
    assert message.prompt_tokens == 10
    assert message.eval_tokens == 3
    assert Assistant.spend(chat.id) == 13
  end

  test "another chat answers while the first one is still writing" do
    Req.Test.stub(AssistantInference.Gemini, fn conn ->
      case conn.method do
        "GET" -> models(conn)
        "POST" ->
          Process.sleep(300)
          sse(conn, [%{"text" => "поздно"}], %{"promptTokenCount" => 1, "candidatesTokenCount" => 1})
      end
    end)

    {:ok, first} = Assistant.create_chat()
    {:ok, second} = Assistant.create_chat()
    Phoenix.PubSub.subscribe(Assistant.PubSub, "assistant:chat:#{first.id}")
    Phoenix.PubSub.subscribe(Assistant.PubSub, "assistant:chat:#{second.id}")

    assert {:ok, first_turn} = Assistant.submit(first.id, "долгий")
    assert {:ok, second_turn} = Assistant.submit(second.id, "второй")
    assert Assistant.submit(first.id, "ещё") == {:error, :busy}

    first_id = first.id
    second_id = second.id
    assert_receive {:slot, %{phase: :idle, chat_id: ^first_id}}, 2_000
    assert_receive {:slot, %{phase: :idle, chat_id: ^second_id}}, 2_000

    assert Assistant.Journal.get_message(first_turn).status == "complete"
    assert Assistant.Journal.get_message(second_turn).status == "complete"
    assert Assistant.phase(first.id) == :idle
    assert Assistant.phase(second.id) == :idle
  end

  test "empty input and a missing key do not create a turn" do
    {:ok, chat} = Assistant.create_chat()
    assert Assistant.submit(chat.id, "  ") == {:error, :empty}
    assert Assistant.messages(chat.id) == []

    original = Application.fetch_env!(:assistant_inference, :gemini)
    Application.put_env(:assistant_inference, :gemini, %{original | key_path: "missing-gemini.key"})
    on_exit(fn -> Application.put_env(:assistant_inference, :gemini, original) end)

    assert Assistant.provider().key_set == false
    assert Assistant.submit(chat.id, "hi") == {:error, :unavailable}
    assert Assistant.messages(chat.id) == []
  end

  test "manual completion does not write the journal" do
    stub_sequence(fn _ ->
      {[%{"text" => "pong"}], %{"promptTokenCount" => 2, "candidatesTokenCount" => 1, "thoughtsTokenCount" => 0}}
    end)

    assert Assistant.complete("ping") == {:ok, "pong"}
    assert Assistant.Repo.aggregate(Assistant.Journal.Message, :count) == 0
    assert Assistant.spend_total() == 0
  end

  defp stub_sequence(fun) do
    {:ok, agent} = Agent.start_link(fn -> [] end)
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    Req.Test.stub(AssistantInference.Gemini, fn conn ->
      case conn.method do
        "GET" ->
          models(conn)

        "POST" ->
          {:ok, raw, conn} = Plug.Conn.read_body(conn)
          Agent.update(agent, &(&1 ++ [raw]))
          n = Agent.get_and_update(counter, fn n -> {n, n + 1} end)
          {parts, usage} = fun.(n)
          sse(conn, parts, usage)
      end
    end)

    agent
  end

  defp models(conn) do
    model = AssistantInference.Gemini.model()

    body = %{
      "models" => [
        %{
          "name" => "models/#{model}",
          "supportedGenerationMethods" => ["generateContent"]
        }
      ]
    }

    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(200, Jason.encode!(body))
  end

  defp sse(conn, parts, usage) do
    payload = %{
      "candidates" => [%{"content" => %{"parts" => parts}}],
      "usageMetadata" => usage
    }

    conn
    |> Plug.Conn.put_resp_content_type("text/event-stream")
    |> Plug.Conn.send_resp(200, "data: #{Jason.encode!(payload)}\n\n")
  end
end
