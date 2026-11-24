defmodule Cards.Application do
  use Application

  @impl true
  def start(_type, _args) do
    Supervisor.start_link([Cards], strategy: :one_for_one, name: Cards.Supervisor)
  end
end
