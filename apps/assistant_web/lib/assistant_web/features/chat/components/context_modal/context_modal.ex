defmodule AssistantWeb.Features.Chat.Components.ContextModal do
  use Phoenix.Component

  alias AssistantWeb.Shared.Components.CircleButton

  embed_templates("context_modal*")

  attr(:open, :boolean, required: true)
  attr(:draft, :string, required: true)
  attr(:reason, :string, default: nil)

  def context_modal(assigns)
end
