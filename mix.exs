#
# Copyright (C) 2017 Ispirata Srl
#
# This file is part of Astarte.
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#

defmodule Astarte.VMQ.Plugin.Mixfile do
  use Mix.Project

  def project do
    [
      app: :astarte_vmq_plugin,
      version: "0.1.0",
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env),
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      deps: deps() ++ astarte_required_modules(System.get_env("ASTARTE_IN_UMBRELLA"))
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :amqp],
      mod: {Astarte.VMQ.Plugin.Application, []},
      env: [
        vmq_plugin_hooks: [
          {:auth_on_publish, Astarte.VMQ.Plugin, :auth_on_publish, 6, []},
          {:auth_on_register, Astarte.VMQ.Plugin, :auth_on_register, 5, []},
          {:auth_on_subscribe, Astarte.VMQ.Plugin, :auth_on_subscribe, 3, []},
          {:on_client_offline, Astarte.VMQ.Plugin, :on_client_offline, 1, []},
          {:on_client_gone, Astarte.VMQ.Plugin, :on_client_gone, 1, []},
          {:on_publish, Astarte.VMQ.Plugin, :on_publish, 6, []},
          {:on_register, Astarte.VMQ.Plugin, :on_register, 3, []}
        ]
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp astarte_required_modules("true") do
    [
      {:astarte_rpc, in_umbrella: true}
    ]
  end

  defp astarte_required_modules(_) do
    [
      {:astarte_rpc, git: "https://git.ispirata.com/Astarte-NG/astarte_rpc"}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:amqp, "~> 1.0"},
      {:vernemq_dev, github: "erlio/vernemq_dev"},
      {:excoveralls, "~> 0.7", only: :test},
      {:distillery, "~> 1.5", runtime: false}
    ]
  end
end
