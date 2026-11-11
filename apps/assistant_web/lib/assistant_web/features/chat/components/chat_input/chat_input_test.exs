defmodule AssistantWeb.Features.Chat.Components.ChatInputTest do
  use ExUnit.Case, async: true

  alias AssistantWeb.Features.Chat.Components.ChatInput
  alias Phoenix.LiveView.AsyncResult

  test "caption shows context and a balance when the provider reports one" do
    meter =
      AsyncResult.ok(AsyncResult.loading(), %{
        used: 1_048_576,
        limit: 1_048_576,
        balance: %{currency: "USD", cents: 300}
      })

    assert ChatInput.caption(meter) == "1 048 576 / 1 048 576 · $3.00"
  end

  test "caption stays empty until both context numbers exist" do
    meter = AsyncResult.ok(AsyncResult.loading(), %{used: 12, limit: nil, balance: nil})
    assert ChatInput.caption(meter) == ""
  end
end
