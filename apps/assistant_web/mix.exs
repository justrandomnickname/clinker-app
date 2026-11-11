defmodule AssistantWeb.MixProject do
  use Mix.Project

  def project do
    [
      app: :assistant_web,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      test_paths: ["test", "lib/assistant_web/features", "lib/assistant_web/shared"],
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {AssistantWeb.Application, []}
    ]
  end

  defp deps do
    [
      {:assistant, in_umbrella: true},
      {:phoenix, "~> 1.7.14"},
      {:phoenix_live_view, "~> 1.0"},
      {:bandit, "~> 1.6"},
      {:jason, "~> 1.4"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:mdex, "~> 0.14"},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev}
    ]
  end

  defp aliases do
    [
      "assets.build": ["tailwind assistant_web"],
      "assets.deploy": ["tailwind assistant_web --minify"]
    ]
  end
end
