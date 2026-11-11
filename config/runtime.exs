import Config

root = Path.expand("..", __DIR__)
config_path = Path.join(root, "assistant.json")
inference = config_path |> File.read!() |> Jason.decode!()

model = inference["gemini_model"] || raise "assistant.json needs gemini_model"
prompt_rel = inference["system_prompt_path"] || "prompts/system.md"

config :assistant, :system_prompt_path, Path.expand(prompt_rel, root)

config :assistant_inference, :gemini, %{
  model: model,
  key_path: Path.join(root, "gemini.key"),
  base_url: "https://generativelanguage.googleapis.com"
}

if config_env() != :test do
  host = inference["host"] || "127.0.0.1"

  if host != "127.0.0.1" do
    raise "localhost only, assistant.json host must be 127.0.0.1"
  end

  port = inference["port"] || 4000

  config :assistant, Assistant.Repo,
    database: Path.join(root, "apps/assistant/priv/assistant.db"),
    pool_size: 1

  config :assistant, :http, %{port: port, ip: {127, 0, 0, 1}}

  config :assistant_web, AssistantWeb.Endpoint,
    http: [
      ip: {127, 0, 0, 1},
      port: port,
      thousand_island_options: [read_timeout: 15 * 60 * 1000]
    ],
    server: true
end
