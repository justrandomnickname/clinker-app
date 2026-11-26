defmodule AssistantWeb.Shared.Components.Icon do
  use Phoenix.Component

  embed_templates("icon*")

  attr :variant, :string,
    values: ["Send", "Burger", "Add", "Close", "Switch-Context"],
    default: "Send"

  def icon(assigns)

  defp src("Burger"), do: "/icons/burger.svg"
  defp src("Add"), do: "/icons/add.svg"
  defp src("Close"), do: "/icons/close.svg"
  defp src("Switch-Context"), do: "/icons/switch-context.svg"
  defp src(_variant), do: "/icons/send.svg"
end
