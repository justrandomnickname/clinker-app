defmodule AssistantWeb.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [AssistantWeb.Endpoint]
    Supervisor.start_link(children, strategy: :one_for_one, name: AssistantWeb.Supervisor)
  end
end
