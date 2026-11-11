defmodule Assistant.Repo do
  use Ecto.Repo,
    otp_app: :assistant,
    adapter: Ecto.Adapters.SQLite3
end
