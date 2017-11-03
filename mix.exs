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
      mod: {Astarte.VMQ.Plugin.Application, []},
      env: [
        vmq_plugin_hooks:
          [
            {:auth_on_publish, Astarte.VMQ.Plugin, :auth_on_publish, 6, []},
            {:auth_on_register, Astarte.VMQ.Plugin, :auth_on_register, 5, []},
            {:auth_on_subscribe, Astarte.VMQ.Plugin, :auth_on_subscribe, 3, []},
            {:on_client_wakeup, Astarte.VMQ.Plugin, :on_client_wakeup, 1, []},
            {:on_client_offline, Astarte.VMQ.Plugin, :on_client_offline, 1, []},
            {:on_client_gone, Astarte.VMQ.Plugin, :on_client_gone, 1, []},
            {:on_publish, Astarte.VMQ.Plugin, :on_publish, 6, []},
            {:on_register, Astarte.VMQ.Plugin, :on_register, 3, []},
          ],
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:amqp, "~> 1.0.0-pre.2"},

      {:excoveralls, "~> 0.7", only: :test},
      {:distillery, "~> 1.5", runtime: false}
    ]
  end
end
