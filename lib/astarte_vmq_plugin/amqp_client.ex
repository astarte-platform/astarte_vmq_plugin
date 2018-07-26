#
# Copyright (C) 2017-2018 Ispirata Srl
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

defmodule Astarte.VMQ.Plugin.AMQPClient do
  require Logger
  use GenServer

  alias AMQP.Basic
  alias AMQP.Channel
  alias AMQP.Connection
  alias Astarte.VMQ.Plugin.Config

  @connection_backoff 10000

  # API

  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def publish(payload, opts \\ []) do
    GenServer.call(__MODULE__, {:publish, payload, opts})
  end

  # Server callbacks

  def init(_args) do
    send(self(), :try_to_connect)
    {:ok, :not_connected}
  end

  def terminate(reason, %Channel{conn: conn} = chan) do
    Logger.warn("AMQPClient terminated with reason #{inspect(reason)}")
    Channel.close(chan)
    Connection.close(conn)
  end

  def terminate(reason, _state) do
    Logger.warn("AMQPClient terminated with reason #{inspect(reason)}")
  end

  def handle_call({:publish, _payload, _opts}, _from, :not_connected = state) do
    {:reply, {:error, :not_connected}, state}
  end

  def handle_call({:publish, payload, opts}, _from, chan) do
    # TODO: handle basic.return
    full_opts =
      opts
      |> Keyword.put(:persistent, true)
      |> Keyword.put(:mandatory, true)

    res = Basic.publish(chan, "", Config.queue_name(), payload, full_opts)

    if Config.mirror_queue_name() do
      Basic.publish(chan, "", Config.mirror_queue_name(), payload, full_opts)
    end

    {:reply, res, chan}
  end

  def handle_info(:try_to_connect, _state) do
    with {:ok, channel} <- connect() do
      {:noreply, channel}
    else
      {:error, :not_connected} ->
        {:noreply, :not_connected}
    end
  end

  def handle_info({:DOWN, _, :process, _pid, reason}, _state) do
    Logger.warn("RabbitMQ connection lost: #{inspect(reason)}. Trying to reconnect...")
    with {:ok, channel} <- connect() do
      {:noreply, channel}
    else
      {:error, :not_connected} ->
        {:noreply, :not_connected}
    end
  end

  defp connect do
    with {:ok, conn} <- Connection.open(Config.amqp_options()),
         # Get notifications when the connection goes down
         {:ok, chan} <- Channel.open(conn),
         Process.monitor(conn.pid) do
      {:ok, chan}
    else
      {:error, reason} ->
        Logger.warn("RabbitMQ Connection error: " <> inspect(reason))
        retry_connection_after(@connection_backoff)
        {:error, :not_connected}

      :error ->
        Logger.warn("Unknown RabbitMQ connection error")
        retry_connection_after(@connection_backoff)
        {:error, :not_connected}
    end
  end

  defp retry_connection_after(backoff) do
    Logger.warn("Retrying connection in #{backoff} ms")
    Process.send_after(self(), :try_to_connect, backoff)
  end
end
