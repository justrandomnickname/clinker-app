defmodule AssistantInference.Gemini.DecoderTest do
  use ExUnit.Case, async: true

  alias AssistantInference.Gemini.Decoder

  test "thought and text stay apart, empty part adds nothing" do
    payload = %{
      "candidates" => [
        %{
          "content" => %{
            "parts" => [
              %{"text" => "", "thought" => true},
              %{"text" => "думаю", "thought" => true},
              %{"text" => "ответ"}
            ]
          }
        }
      ],
      "usageMetadata" => %{
        "promptTokenCount" => 5,
        "candidatesTokenCount" => 2,
        "thoughtsTokenCount" => 3
      }
    }

    {events, rest} = Decoder.take("", "data: " <> Jason.encode!(payload) <> "\n")

    assert rest == ""
    assert events == [{:thinking, "думаю"}, {:text, "ответ"}, {:usage, 5, 5}]
  end

  test "a split chunk waits for the rest of the line" do
    {events, rest} = Decoder.take("", "data: {\"cand")
    assert events == []
    assert rest == "data: {\"cand"

    payload = %{"candidates" => [%{"content" => %{"parts" => [%{"text" => "a"}]}}]}
    json = Jason.encode!(payload)
    head = binary_part(json, 0, 4)
    tail = binary_part(json, 4, byte_size(json) - 4)
    {events, rest} = Decoder.take("data: " <> head, tail <> "\n")
    assert events == [{:text, "a"}]
    assert rest == ""
  end
end
