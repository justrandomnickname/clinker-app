defmodule Assistant.Repo do
  use Ecto.Repo,
    otp_app: :assistant,
    adapter: Application.compile_env(:assistant, [Assistant.Repo, :adapter], Ecto.Adapters.SQLite3)
end
