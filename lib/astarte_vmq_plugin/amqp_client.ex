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

  def publish(payload, timestamp, headers, opts \\ []) do
    GenServer.call(__MODULE__, {:publish, payload, timestamp, headers, opts})
  end

  # Server callbacks

  def init(_args) do
    rabbitmq_connect(false)
  end

  def terminate(_reason, %Channel{conn: conn} = chan) do
    Channel.close(chan)
    Connection.close(conn)
  end

  def handle_call({:publish, payload, timestamp, headers, opts}, _from, chan) do
    # TODO: handle basic.return
    full_opts =
      opts
      |> Keyword.put(:timestamp, timestamp)
      |> Keyword.put(:headers, headers)
      |> Keyword.put(:persistent, true)
      |> Keyword.put(:mandatory, true)

    res = Basic.publish(chan, "", Config.queue_name(), payload, full_opts)

    if Config.mirror_queue_name() do
      Basic.publish(chan, "", Config.mirror_queue_name(), payload, full_opts)
    end

    {:reply, res, chan}
  end

  def handle_info({:try_to_connect}, _state) do
    {:ok, new_state} = rabbitmq_connect()
    {:noreply, new_state}
  end

  def handle_info({:DOWN, _, :process, _pid, reason}, _state) do
    Logger.warn("RabbitMQ connection lost: #{inspect(reason)}. Trying to reconnect...")
    {:ok, new_state} = rabbitmq_connect()
    {:noreply, new_state}
  end

  defp rabbitmq_connect(retry \\ true) do
    with {:ok, conn} <- Connection.open(Config.amqp_options()),
         # Get notifications when the connection goes down
         Process.monitor(conn.pid),
         {:ok, chan} <- Channel.open(conn) do
      {:ok, chan}
    else
      {:error, reason} ->
        Logger.warn("RabbitMQ Connection error: " <> inspect(reason))
        maybe_retry(retry)

      :error ->
        Logger.warn("Unknown RabbitMQ connection error")
        maybe_retry(retry)
    end
  end

  defp maybe_retry(retry) do
    if retry do
      Logger.warn("Retrying connection in #{@connection_backoff} ms")
      :erlang.send_after(@connection_backoff, :erlang.self(), {:try_to_connect})
      {:ok, :not_connected}
    else
      {:stop, :connection_failed}
    end
  end
end
