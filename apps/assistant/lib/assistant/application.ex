defmodule Assistant.Application do
  use Application

  alias Assistant.Repo.Migrator

  @impl true
  def start(_type, _args) do
    Supervisor.start_link(
      [
        Assistant.Repo,
        Migrator,
        {Registry, keys: :unique, name: Assistant.Reply.Registry},
        {DynamicSupervisor, name: Assistant.Reply.Supervisor, strategy: :one_for_one},
        {Phoenix.PubSub, name: Assistant.PubSub},
        {Task.Supervisor, name: Assistant.TaskSupervisor}
      ],
      strategy: :one_for_one,
      name: Assistant.Supervisor
    )
  end
end
