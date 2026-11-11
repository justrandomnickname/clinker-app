defmodule Assistant.Repo.Migrator do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(_opts) do
    path = Application.app_dir(:assistant, "priv/repo/migrations")
    Ecto.Migrator.run(Assistant.Repo, path, :up, all: true)
    Assistant.Journal.ensure_provider!("gemini")
    Assistant.Journal.interrupt_open_partials()
    :ignore
  end
end
