defmodule Astarte.VMQ.Plugin.Mixfile do
  use Mix.Project

  def project do
    [
      app: :astarte_vmq_plugin,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: ["coveralls": :test, "coveralls.detail": :test, "coveralls.post": :test, "coveralls.html": :test],
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Astarte.VMQ.Plugin.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:excoveralls, "~> 0.7", only: :test},
      {:distillery, "~> 1.5", runtime: false}
    ]
  end
end
