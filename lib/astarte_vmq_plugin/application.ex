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

defmodule Astarte.VMQ.Plugin.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias Astarte.VMQ.Plugin.RPC.Handler, as: RPCHandler
  alias Astarte.RPC.Protocol.VMQ.Plugin, as: Protocol
  alias Astarte.VMQ.Plugin.Config

  def start(_type, _args) do
    Config.init()

    # List all child processes to be supervised
    children = [
      Astarte.VMQ.Plugin.AMQPClient,
      {Astarte.VMQ.Plugin.Publisher, [Config.registry_mfa()]},
      {Astarte.RPC.AMQP.Server, [amqp_queue: Protocol.amqp_queue(), handler: RPCHandler]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Astarte.VMQ.Plugin.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
