import Config

config :logger, level: :warning

db_id = "#{:erlang.system_time(:nanosecond)}_#{:rand.uniform(1_000_000)}"

config :assistant, Assistant.Repo,
  database: Path.expand("../apps/assistant/priv/assistant_test_#{db_id}.db", __DIR__),
  pool_size: 1,
  log: false

config :assistant, :flush_interval_ms, 10

config :assistant_web, AssistantWeb.Endpoint, server: false

config :assistant_inference, :req_options, plug: {Req.Test, AssistantInference.Gemini}
