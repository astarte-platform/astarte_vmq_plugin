defmodule Astarte.VMQ.Plugin.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias Astarte.VMQ.Plugin.Config

  def start(_type, _args) do
    Config.init()

    # List all child processes to be supervised
    children = [
      Astarte.VMQ.Plugin.AMQPClient
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Astarte.VMQ.Plugin.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
