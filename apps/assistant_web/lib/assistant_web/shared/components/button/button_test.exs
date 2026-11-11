defmodule AssistantWeb.Shared.Components.ButtonTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias AssistantWeb.Shared.Components.Button

  test "primary button shows its label" do
    html =
      render_component(&Button.button/1,
        type: "submit",
        inner_block: [%{inner_block: fn _, _ -> "Отправить" end}]
      )

    assert html =~ "Отправить"
    assert html =~ ~s(type="submit")
    assert html =~ "bg-brand"
    assert html =~ "rounded-bttn-md"
    assert html =~ "drop-shadow-brand"
    assert html =~ "px-figma-xl"
    refute html =~ "border-"
    refute html =~ "disabled"
  end

  test "disabled is set only when asked" do
    html =
      render_component(&Button.button/1,
        disabled: true,
        inner_block: [%{inner_block: fn _, _ -> "Отправить" end}]
      )

    assert html =~ "disabled"
  end
end
