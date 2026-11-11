defmodule AssistantWeb.Shared.Components.Button do
  use Phoenix.Component

  embed_templates("button*")

  attr :variant, :string, values: ["primary"], default: "primary"
  attr :type, :string, default: "button"
  attr :disabled, :boolean, default: false
  attr :rest, :global

  slot :inner_block, required: true

  def button(assigns)
end
