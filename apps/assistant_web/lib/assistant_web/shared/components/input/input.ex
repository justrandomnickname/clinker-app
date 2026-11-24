defmodule AssistantWeb.Shared.Components.Input do
  use Phoenix.Component

  embed_templates("input*")

  attr :name, :string, required: true
  attr :value, :string, required: true
  attr :placeholder, :string, required: true
  attr :rest, :global, include: ~w(autocomplete)

  def input(assigns)
end
