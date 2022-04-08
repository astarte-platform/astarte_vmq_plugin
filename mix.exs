#
# This file is part of Astarte.
#
# Copyright 2017-2022 Ispirata Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

defmodule Astarte.VMQ.Plugin.Mixfile do
  use Mix.Project

  def project do
    [
      app: :astarte_vmq_plugin,
      version: "1.0.2",
      elixir: "~> 1.11",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      dialyzer_cache_directory: dialyzer_cache_directory(Mix.env()),
      deps: deps() ++ astarte_required_modules(System.get_env("ASTARTE_IN_UMBRELLA"))
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:lager, :logger, :amqp],
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

  defp dialyzer_cache_directory(:ci) do
    "dialyzer_cache"
  end

  defp dialyzer_cache_directory(_) do
    nil
  end

  defp astarte_required_modules("true") do
    [
      {:astarte_rpc, in_umbrella: true}
    ]
  end

  defp astarte_required_modules(_) do
    [
      {:astarte_rpc, "~> 1.0.2"}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:amqp, "~> 2.1"},
      {:vernemq_dev, github: "vernemq/vernemq_dev"},
      {:excoveralls, "~> 0.12", only: :test},
      {:pretty_log, "~> 0.1"},
      {:dialyzex, github: "Comcast/dialyzex", only: [:dev, :ci]}
    ]
  end
end
