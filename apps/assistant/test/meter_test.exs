defmodule Assistant.MeterTest do
  use ExUnit.Case, async: false

  setup do
    Req.Test.set_req_test_to_shared()
    Assistant.Repo.delete_all(Assistant.Journal.Message)
    Assistant.Repo.delete_all(Assistant.Journal.Chat)

    Req.Test.stub(AssistantInference.Gemini, fn conn ->
      model = AssistantInference.Gemini.model()

      body =
        Jason.encode!(%{
          "models" => [
            %{
              "name" => "models/#{model}",
              "inputTokenLimit" => 1_048_576,
              "supportedGenerationMethods" => ["generateContent"]
            }
          ]
        })

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, body)
    end)

    :ok
  end

  test "meter uses the latest prompt and does not invent a balance" do
    {:ok, chat} = Assistant.create_chat()

    Assistant.Repo.insert!(%Assistant.Journal.Message{
      chat_id: chat.id,
      seq: 1,
      role: "assistant",
      content: "первый",
      status: "complete",
      prompt_tokens: 10
    })

    Assistant.Repo.insert!(%Assistant.Journal.Message{
      chat_id: chat.id,
      seq: 2,
      role: "assistant",
      content: "второй",
      status: "complete",
      prompt_tokens: 40
    })

    meter = Assistant.meter(chat.id)
    assert meter.used == 40
    assert meter.balance == nil

    if AssistantInference.Gemini.key_set?() do
      assert meter.limit == 1_048_576
    else
      assert meter.limit == nil
    end
  end
end
