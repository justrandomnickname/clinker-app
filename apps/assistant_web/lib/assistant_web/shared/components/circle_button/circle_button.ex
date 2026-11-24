defmodule AssistantWeb.Shared.Components.CircleButton do
  use Phoenix.Component

  embed_templates("circle_button*")

  attr :type, :string, default: "button"
  attr :disabled, :boolean, default: false
  attr :rest, :global

  def circle_button(assigns)
end
