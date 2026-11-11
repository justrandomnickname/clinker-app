defmodule AssistantInference.GeminiTest do
  use ExUnit.Case, async: true

  test "token limit comes from the listed model" do
    models = [
      %{"name" => "models/other", "inputTokenLimit" => 10},
      %{"name" => "models/gemini", "inputTokenLimit" => 1_048_576}
    ]

    assert AssistantInference.Gemini.token_limit(models, "gemini") == 1_048_576
    assert AssistantInference.Gemini.token_limit(models, "missing") == nil
    assert AssistantInference.Gemini.balance() == nil
  end
end
