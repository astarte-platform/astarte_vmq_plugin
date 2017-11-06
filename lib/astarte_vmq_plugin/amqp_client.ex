defmodule Astarte.VMQ.Plugin.AMQPClient do
  require Logger
  use GenServer

  alias AMQP.Basic
  alias AMQP.Channel
  alias AMQP.Connection
  alias AMQP.Exchange
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

  def handle_call({:publish, payload, timestamp, headers, opts}, _from, chan) do
    full_opts =
      opts
      |> Keyword.put(:timestamp, timestamp)
      |> Keyword.put(:headers, headers)
      |> Keyword.put(:persistent, true)
      |> Keyword.put(:mandatory, true) # TODO: handle basic.return

    res = Basic.publish(chan, Config.exchange_name(), "", payload, full_opts)

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
         {:ok, chan} <- Channel.open(conn),
         :ok <- Exchange.fanout(chan, Config.exchange_name(), durable: true) do

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
