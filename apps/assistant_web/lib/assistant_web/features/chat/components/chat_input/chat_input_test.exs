defmodule AssistantWeb.Features.Chat.Components.ChatInputTest do
  use ExUnit.Case, async: true

  alias AssistantWeb.Features.Chat.Components.ChatInput
  alias Phoenix.LiveView.AsyncResult

  test "caption rounds the context window" do
    assert ChatInput.caption(meter(4_839, 1_048_576)) == "4.8k / 1kk"
    assert ChatInput.caption(meter(4_900, 1_100_000)) == "4.9k / 1.1kk"
    assert ChatInput.caption(meter(1_100_000, 1_048_576)) == "1.1kk / 1kk"
  end

  test "caption stays empty until both context numbers exist" do
    meter = AsyncResult.ok(AsyncResult.loading(), %{used: 12, limit: nil, balance: nil})
    assert ChatInput.caption(meter) == ""
  end

  defp meter(used, limit) do
    AsyncResult.ok(AsyncResult.loading(), %{used: used, limit: limit, balance: nil})
  end
end
