defmodule Assistant.MixProject do
  use Mix.Project

  def project do
    [
      app: :assistant,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Assistant.Application, []}
    ]
  end

  defp deps do
    [
      {:assistant_inference, in_umbrella: true},
      {:ecto_sql, "~> 3.12"},
      {:ecto_sqlite3, "~> 0.17"},
      {:postgrex, "~> 0.19"},
      {:phoenix_pubsub, "~> 2.1"},
      {:plug, "~> 1.16", only: :test}
    ]
  end
end
