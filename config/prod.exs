import Config

config :logger, level: :info

config :assistant, Assistant.Repo, adapter: Ecto.Adapters.Postgres
