#
# This file is part of Astarte.
#
# Copyright 2022 SECO Mind Srl
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

defmodule Astarte.VMQ.Plugin.Connection.SynchronizerTest do
  use ExUnit.Case

  alias AMQP.{Channel, Connection, Queue}
  alias Astarte.VMQ.Plugin.Config
  alias Astarte.VMQ.Plugin.Connection.Synchronizer
  alias Astarte.VMQ.Plugin.Connection.Synchronizer.Supervisor, as: SynchronizerSupervisor

  @device_id :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  @realm "test"
  @device_base_path "#{@realm}/#{@device_id}"
  @queue_name "#{Config.data_queue_prefix()}0"

  setup_all do
    amqp_opts = Config.amqp_options()
    {:ok, conn} = Connection.open(amqp_opts)
    {:ok, chan} = Channel.open(conn)
    Queue.declare(chan, @queue_name)
    {:ok, chan: chan}
  end

  setup %{chan: chan} do
    test_pid = self()

    {:ok, consumer_tag} =
      Queue.subscribe(chan, @queue_name, fn payload, meta ->
        send(test_pid, {:amqp_msg, payload, meta})
      end)

    on_exit(fn ->
      Queue.unsubscribe(chan, consumer_tag)
    end)

    :ok
  end

  test "Standard connection flow" do
    connection_timestamp = now_us_x10_timestamp()

    # no reconciler
    assert Registry.lookup(AstarteVMQPluginConnectionSynchronizer.Registry, @device_base_path) ==
             []

    # start the reconciler
    reconciler_pid = get_connection_reconciler_process!(@device_base_path)

    assert Registry.lookup(AstarteVMQPluginConnectionSynchronizer.Registry, @device_base_path) ==
             [
               {reconciler_pid, nil}
             ]

    # connect the device
    Synchronizer.handle_connection(reconciler_pid, connection_timestamp)

    # Make sure messages arrived
    Process.sleep(100)

    # the reconciler should be dead by now
    assert Registry.lookup(AstarteVMQPluginConnectionSynchronizer.Registry, @device_base_path) ==
             []

    assert_receive {:amqp_msg, "",
                    %{headers: connection_headers, timestamp: ^connection_timestamp}}

    assert %{"x_astarte_msg_type" => "connection"} = amqp_headers_to_map(connection_headers)
  end

  test "Ordered disconnection and reconnection events are correctly ordered" do
    connection_timestamp = now_us_x10_timestamp()
    disconnection_timestamp = connection_timestamp + 1
    reconnection_timestamp = connection_timestamp + 2

    # No reconciler
    assert Registry.lookup(AstarteVMQPluginConnectionSynchronizer.Registry, @device_base_path) ==
             []

    # Start the reconciler
    reconciler_pid = get_connection_reconciler_process!(@device_base_path)

    assert Registry.lookup(AstarteVMQPluginConnectionSynchronizer.Registry, @device_base_path) ==
             [
               {reconciler_pid, nil}
             ]

    # Connect the device (right now we don't care about concurrency)
    Synchronizer.handle_connection(reconciler_pid, connection_timestamp)

    # Make sure messages arrived
    Process.sleep(100)

    # The reconciler should be dead by now
    assert Registry.lookup(AstarteVMQPluginConnectionSynchronizer.Registry, @device_base_path) ==
             []

    assert_receive {:amqp_msg, "",
                    %{headers: connection_headers, timestamp: ^connection_timestamp}}

    assert %{"x_astarte_msg_type" => "connection"} = amqp_headers_to_map(connection_headers)

    # Now, another reconciler comes in hand
    another_reconciler_pid = get_connection_reconciler_process!(@device_base_path)

    # Correctly ordered events: disconnection before reconnection
    # we use async tasks to simulate concurrency because handle_[dis]connection is sync
    Task.start(fn ->
      Synchronizer.handle_disconnection(another_reconciler_pid, disconnection_timestamp)
    end)

    Task.start(fn ->
      Synchronizer.handle_connection(another_reconciler_pid, reconnection_timestamp)
    end)

    # Make sure messages arrived
    Process.sleep(100)

    # The other reconciler should be dead, too, by now
    assert Registry.lookup(AstarteVMQPluginConnectionSynchronizer.Registry, @device_base_path) ==
             []

    # Disconnect arrived before (re)connect
    assert {:messages, [disconnect_message, reconnect_message]} = Process.info(self(), :messages)

    assert {:amqp_msg, "", %{headers: disconnection_headers, timestamp: ^disconnection_timestamp}} =
             disconnect_message

    assert %{"x_astarte_msg_type" => "disconnection"} = amqp_headers_to_map(disconnection_headers)

    assert {:amqp_msg, "", %{headers: reconnection_headers, timestamp: ^reconnection_timestamp}} =
             reconnect_message

    assert %{"x_astarte_msg_type" => "connection"} = amqp_headers_to_map(reconnection_headers)
  end

  test "Disconnection and reconnection events swapped, but near in time, are correctly reordered" do
    connection_timestamp = now_us_x10_timestamp()
    disconnection_timestamp = connection_timestamp + 1
    reconnection_timestamp = connection_timestamp + 2

    # No reconciler
    assert Registry.lookup(AstarteVMQPluginConnectionSynchronizer.Registry, @device_base_path) ==
             []

    # Start the reconciler
    reconciler_pid = get_connection_reconciler_process!(@device_base_path)

    assert Registry.lookup(AstarteVMQPluginConnectionSynchronizer.Registry, @device_base_path) ==
             [
               {reconciler_pid, nil}
             ]

    # Connect the device (right now we don't care about concurrency)
    Synchronizer.handle_connection(reconciler_pid, connection_timestamp)

    # Make sure messages arrived
    Process.sleep(100)

    # The reconciler should be dead by now
    assert Registry.lookup(AstarteVMQPluginConnectionSynchronizer.Registry, @device_base_path) ==
             []

    assert_receive {:amqp_msg, "",
                    %{headers: connection_headers, timestamp: ^connection_timestamp}}

    assert %{"x_astarte_msg_type" => "connection"} = amqp_headers_to_map(connection_headers)

    # Now, another reconciler comes in hand
    another_reconciler_pid = get_connection_reconciler_process!(@device_base_path)

    # Make some strange things à la VMQ, like a connection just before a disconnection
    # we use async tasks to simulate concurrency because handle_[dis]connection is sync
    Task.start(fn ->
      Synchronizer.handle_connection(another_reconciler_pid, reconnection_timestamp)
    end)

    Task.start(fn ->
      Synchronizer.handle_disconnection(another_reconciler_pid, disconnection_timestamp)
    end)

    # Make sure messages arrived
    Process.sleep(100)

    # The other reconciler should be dead, too, by now
    assert Registry.lookup(AstarteVMQPluginConnectionSynchronizer.Registry, @device_base_path) ==
             []

    # Disconnect arrived before (re)connect
    assert {:messages, [disconnect_message, reconnect_message]} = Process.info(self(), :messages)

    assert {:amqp_msg, "", %{headers: disconnection_headers, timestamp: ^disconnection_timestamp}} =
             disconnect_message

    assert %{"x_astarte_msg_type" => "disconnection"} = amqp_headers_to_map(disconnection_headers)

    assert {:amqp_msg, "", %{headers: reconnection_headers, timestamp: ^reconnection_timestamp}} =
             reconnect_message

    assert %{"x_astarte_msg_type" => "connection"} = amqp_headers_to_map(reconnection_headers)
  end

  defp amqp_headers_to_map(headers) do
    Enum.reduce(headers, %{}, fn {key, _type, value}, acc ->
      Map.put(acc, key, value)
    end)
  end

  defp now_us_x10_timestamp do
    DateTime.utc_now()
    |> DateTime.to_unix(:microsecond)
    |> Kernel.*(10)
  end

  defp get_connection_reconciler_process!(client_id) do
    case SynchronizerSupervisor.start_child(client_id: client_id) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
  end
end
