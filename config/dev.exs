import Config

config :logger, level: :info

config :assistant_web, AssistantWeb.Endpoint,
  code_reloader: true,
  watchers: [
    tailwind: {Tailwind, :install_and_run, [:assistant_web, ~w(--watch=always)]}
  ],
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/assistant_web/.*(ex|heex)$"
    ]
  ]
