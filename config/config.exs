import Config

config :phoenix, :json_library, Jason

config :tailwind,
  version: "4.3.0",
  assistant_web: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("../apps/assistant_web", __DIR__)
  ]
config :assistant, ecto_repos: [Assistant.Repo]

config :assistant_web, AssistantWeb.Endpoint,
  url: [host: "127.0.0.1"],
  check_origin: :conn,
  adapter: Bandit.PhoenixAdapter,
  secret_key_base: String.duplicate("b", 64),
  render_errors: [
    formats: [html: AssistantWeb.Shell.ErrorHTML, json: AssistantWeb.Shell.ErrorJSON],
    layout: false
  ],
  pubsub_server: Assistant.PubSub,
  live_view: [signing_salt: "assistant-live"]

import_config "#{config_env()}.exs"
