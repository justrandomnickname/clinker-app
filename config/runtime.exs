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
end

if config_env() == :dev do
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

if config_env() == :prod do
  secret_key_base = System.get_env("SECRET_KEY_BASE", "") |> String.trim()

  if byte_size(secret_key_base) < 64 do
    raise "SECRET_KEY_BASE must be set to at least 64 bytes"
  end

  port = String.to_integer(System.get_env("PORT") || "4000")
  database_url = System.get_env("DATABASE_URL", "") |> String.trim()

  if database_url == "" do
    raise "DATABASE_URL is missing"
  end

  db_host = URI.parse(database_url).host || raise "DATABASE_URL has no host"

  config :assistant, Assistant.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "2"),
    ssl: [
      verify: :verify_peer,
      cacerts: :public_key.cacerts_get(),
      server_name_indication: String.to_charlist(db_host),
      customize_hostname_check: [
        match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
      ]
    ]

  config :assistant, :http, %{port: port, ip: {0, 0, 0, 0}}

  url = [scheme: "https", port: 443]

  url =
    case System.get_env("PHX_HOST", "") |> String.trim() do
      "" -> url
      phx_host -> Keyword.put(url, :host, phx_host)
    end

  config :assistant_web, AssistantWeb.Endpoint,
    url: url,
    check_origin: true,
    http: [
      ip: {0, 0, 0, 0},
      port: port,
      thousand_island_options: [read_timeout: 15 * 60 * 1000]
    ],
    force_ssl: [rewrite_on: [:x_forwarded_proto]],
    secret_key_base: secret_key_base,
    server: true
end
