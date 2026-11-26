defmodule AssistantWeb.Shared.Components.CircleButton do
  use Phoenix.Component

  alias AssistantWeb.Shared.Components.Icon

  embed_templates("circle_button*")

  attr :variant, :string,
    values: ["Send", "Burger", "Add", "Close", "Switch-Context"],
    default: "Send"

  attr :type, :string, default: "button"
  attr :disabled, :boolean, default: false
  attr :rest, :global

  def circle_button(assigns)
end
