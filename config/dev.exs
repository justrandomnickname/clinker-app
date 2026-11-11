import Config

config :logger, level: :info

config :assistant_web, AssistantWeb.Endpoint,
  watchers: [
    tailwind: {Tailwind, :install_and_run, [:assistant_web, ~w(--watch=always)]}
  ]
