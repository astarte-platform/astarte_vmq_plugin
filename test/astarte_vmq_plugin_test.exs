#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
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

defmodule Astarte.VMQ.PluginTest do
  use ExUnit.Case
  doctest Astarte.VMQ.Plugin

  alias AMQP.{Channel, Connection, Queue}
  alias Astarte.VMQ.Plugin
  alias Astarte.VMQ.Plugin.Config

  @device_id :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  @other_device_id :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  @realm "test"
  @device_base_path "#{@realm}/#{@device_id}"
  @other_mqtt_user "other"
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

  test "auth_on_register for a device" do
    assert {:ok, modifiers} =
             Plugin.auth_on_register(
               :dontcare,
               {"/", :dontcare},
               @device_base_path,
               :dontcare,
               :dontcare
             )

    assert Keyword.get(modifiers, :subscriber_id) == {"/", @device_base_path}
  end

  test "auth_on_register for non-devices" do
    assert :next =
             Plugin.auth_on_register(
               :dontcare,
               {"/", :dontcare},
               @other_mqtt_user,
               :dontcare,
               :dontcare
             )
  end

  test "partially authorized auth_on_subscribe for devices" do
    authorized_topics = [
      {[@realm, @device_id, "authorizedtopic"], 2},
      {[@realm, @device_id, "otherauthorizedtopic"], 1}
    ]

    unauthorized_topics = [
      {[@realm, @other_device_id, "unauthorizedtopic"], 0},
      {["other_realm", @device_id, "unauthorizedtopic"], 1},
      {["unauthorizedtopic"], 2}
    ]

    topics = unauthorized_topics ++ authorized_topics

    assert {:ok, ^authorized_topics} =
             Plugin.auth_on_subscribe(:dontcare, {:dontcare, @device_base_path}, topics)
  end

  test "fully authorized auth_on_subscribe for devices" do
    topics = [
      {[@realm, @device_id, "authorizedtopic"], 2},
      {[@realm, @device_id, "otherauthorizedtopic"], 1}
    ]

    assert {:ok, ^topics} =
             Plugin.auth_on_subscribe(:dontcare, {:dontcare, @device_base_path}, topics)
  end

  test "not authorized auth_on_subscribe for devices" do
    unauthorized_topics = [
      {[@realm, @other_device_id, "unauthorizedtopic"], 0},
      {["other_realm", @device_id, "unauthorizedtopic"], 1},
      {["unauthorizedtopic"], 2}
    ]

    assert {:error, :unauthorized} =
             Plugin.auth_on_subscribe(
               :dontcare,
               {:dontcare, @device_base_path},
               unauthorized_topics
             )
  end

  test "auth_on_subscribe for non-devices" do
    topics = [
      {["some", "random", "topic"], 1},
      {["another", "random", "topic"], 0},
      {["and", "so", "on"], 2}
    ]

    assert :ok = Plugin.auth_on_subscribe(:dontcare, {:dontcare, @other_mqtt_user}, topics)
  end

  test "authorized auth_on_publish for device" do
    introspection_topic = [@realm, @device_id]
    data_topic = [@realm, @device_id, "com.some.Interface", "some", "path"]
    control_topic = [@realm, @device_id, "control", "some", "path"]

    assert :ok =
             Plugin.auth_on_publish(
               :dontcare,
               {:dontcare, @device_base_path},
               :dontcare,
               introspection_topic,
               :dontcare,
               :dontcare
             )

    assert :ok =
             Plugin.auth_on_publish(
               :dontcare,
               {:dontcare, @device_base_path},
               :dontcare,
               data_topic,
               :dontcare,
               :dontcare
             )

    assert :ok =
             Plugin.auth_on_publish(
               :dontcare,
               {:dontcare, @device_base_path},
               :dontcare,
               control_topic,
               :dontcare,
               :dontcare
             )
  end

  test "unauthorized auth_on_publish for device" do
    other_device_topic = [@realm, @other_device_id, "com.some.Interface", "some", "path"]
    other_realm_topic = ["other_realm", @device_id, "com.some.Interface", "some", "path"]
    out_of_hierarchy_topic = ["some", "topic"]

    assert {:error, :unauthorized} =
             Plugin.auth_on_publish(
               :dontcare,
               {:dontcare, @device_base_path},
               :dontcare,
               other_device_topic,
               :dontcare,
               :dontcare
             )

    assert {:error, :unauthorized} =
             Plugin.auth_on_publish(
               :dontcare,
               {:dontcare, @device_base_path},
               :dontcare,
               other_realm_topic,
               :dontcare,
               :dontcare
             )

    assert {:error, :unauthorized} =
             Plugin.auth_on_publish(
               :dontcare,
               {:dontcare, @device_base_path},
               :dontcare,
               out_of_hierarchy_topic,
               :dontcare,
               :dontcare
             )
  end

  test "authorized auth_on_publish for non-device" do
    introspection_topic = [@realm, @device_id]
    data_topic = [@realm, @device_id, "com.some.Interface", "some", "path"]
    control_topic = [@realm, @device_id, "control", "some", "path"]
    random_topic = ["any", "topic"]

    assert :ok =
             Plugin.auth_on_publish(
               :dontcare,
               {:dontcare, @other_mqtt_user},
               :dontcare,
               introspection_topic,
               :dontcare,
               :dontcare
             )

    assert :ok =
             Plugin.auth_on_publish(
               :dontcare,
               {:dontcare, @other_mqtt_user},
               :dontcare,
               data_topic,
               :dontcare,
               :dontcare
             )

    assert :ok =
             Plugin.auth_on_publish(
               :dontcare,
               {:dontcare, @other_mqtt_user},
               :dontcare,
               control_topic,
               :dontcare,
               :dontcare
             )

    assert :ok =
             Plugin.auth_on_publish(
               :dontcare,
               {:dontcare, @other_mqtt_user},
               :dontcare,
               random_topic,
               :dontcare,
               :dontcare
             )
  end

  test "device on_register" do
    ip_addr = {2, 3, 4, 5}

    Plugin.on_register({ip_addr, :dontcare}, {:dontcare, @device_base_path}, :dontcare)

    assert_receive {:amqp_msg, "",
                    %{headers: headers, timestamp: timestamp, message_id: message_id} = _metadata}

    # 5 seconds
    assert_in_delta timestamp, now_us_x10_timestamp(), 50_000_000

    assert %{
             "x_astarte_vmqamqp_proto_ver" => 1,
             "x_astarte_msg_type" => "connection",
             "x_astarte_realm" => @realm,
             "x_astarte_device_id" => @device_id,
             "x_astarte_remote_ip" => "2.3.4.5"
           } = amqp_headers_to_map(headers)

    assert String.starts_with?(message_id, message_id_prefix(@realm, @device_id, timestamp))
  end

  test "device on_client_gone" do
    Plugin.on_client_gone({:dontcare, @device_base_path})

    assert_receive {:amqp_msg, "",
                    %{headers: headers, timestamp: timestamp, message_id: message_id} = _metadata}

    # 5 seconds
    assert_in_delta timestamp, now_us_x10_timestamp(), 50_000_000

    assert %{
             "x_astarte_vmqamqp_proto_ver" => 1,
             "x_astarte_msg_type" => "disconnection",
             "x_astarte_realm" => @realm,
             "x_astarte_device_id" => @device_id
           } = amqp_headers_to_map(headers)

    assert String.starts_with?(message_id, message_id_prefix(@realm, @device_id, timestamp))
  end

  test "device on_client_offline" do
    Plugin.on_client_offline({:dontcare, @device_base_path})

    assert_receive {:amqp_msg, "",
                    %{headers: headers, timestamp: timestamp, message_id: message_id} = _metadata}

    # 5 seconds
    assert_in_delta timestamp, now_us_x10_timestamp(), 50_000_000

    assert %{
             "x_astarte_vmqamqp_proto_ver" => 1,
             "x_astarte_msg_type" => "disconnection",
             "x_astarte_realm" => @realm,
             "x_astarte_device_id" => @device_id
           } = amqp_headers_to_map(headers)

    assert String.starts_with?(message_id, message_id_prefix(@realm, @device_id, timestamp))
  end

  test "device introspection on_publish" do
    introspection_topic = [@realm, @device_id]
    payload = "com.an.Interface:1:0;com.another.Interface:2:0"

    Plugin.on_publish(
      :dontcare,
      {:dontcare, @device_base_path},
      :dontcare,
      introspection_topic,
      payload,
      :dontcare
    )

    assert_receive {:amqp_msg, ^payload,
                    %{headers: headers, timestamp: timestamp, message_id: message_id} = _metadata}

    # 5 seconds
    assert_in_delta timestamp, now_us_x10_timestamp(), 50_000_000

    assert %{
             "x_astarte_vmqamqp_proto_ver" => 1,
             "x_astarte_msg_type" => "introspection",
             "x_astarte_realm" => @realm,
             "x_astarte_device_id" => @device_id
           } = amqp_headers_to_map(headers)

    assert String.starts_with?(message_id, message_id_prefix(@realm, @device_id, timestamp))
  end

  test "device control on_publish" do
    control_path = "/some/control/path"
    control_topic = [@realm, @device_id, "control"] ++ String.split(control_path, "/", trim: true)
    payload = "payload"

    Plugin.on_publish(
      :dontcare,
      {:dontcare, @device_base_path},
      :dontcare,
      control_topic,
      payload,
      :dontcare
    )

    assert_receive {:amqp_msg, ^payload,
                    %{headers: headers, timestamp: timestamp, message_id: message_id} = _metadata}

    # 5 seconds
    assert_in_delta timestamp, now_us_x10_timestamp(), 50_000_000

    assert %{
             "x_astarte_vmqamqp_proto_ver" => 1,
             "x_astarte_msg_type" => "control",
             "x_astarte_realm" => @realm,
             "x_astarte_device_id" => @device_id,
             "x_astarte_control_path" => ^control_path
           } = amqp_headers_to_map(headers)

    assert String.starts_with?(message_id, message_id_prefix(@realm, @device_id, timestamp))
  end

  test "device data on_publish" do
    path = "/some/data/path"
    interface = "com.my.Interface"
    data_topic = [@realm, @device_id, interface] ++ String.split(path, "/", trim: true)
    payload = "mypayload"

    Plugin.on_publish(
      :dontcare,
      {:dontcare, @device_base_path},
      :dontcare,
      data_topic,
      payload,
      :dontcare
    )

    assert_receive {:amqp_msg, ^payload,
                    %{headers: headers, timestamp: timestamp, message_id: message_id} = _metadata}

    # 5 seconds
    assert_in_delta timestamp, now_us_x10_timestamp(), 50_000_000

    assert %{
             "x_astarte_vmqamqp_proto_ver" => 1,
             "x_astarte_msg_type" => "data",
             "x_astarte_realm" => @realm,
             "x_astarte_device_id" => @device_id,
             "x_astarte_interface" => ^interface,
             "x_astarte_path" => ^path
           } = amqp_headers_to_map(headers)

    assert String.starts_with?(message_id, message_id_prefix(@realm, @device_id, timestamp))
  end

  test "non-device hooks don't send anything" do
    ip_addr = {2, 3, 4, 5}

    Plugin.on_register({ip_addr, :dontcare}, {:dontcare, @other_mqtt_user}, :dontcare)
    Plugin.on_client_gone({:dontcare, @other_mqtt_user})
    Plugin.on_client_offline({:dontcare, @other_mqtt_user})

    introspection_topic = [@realm, @device_id]
    payload = "com.an.Interface:1:0;com.another.Interface:2:0"

    Plugin.on_publish(
      :dontcare,
      {:dontcare, @other_mqtt_user},
      :dontcare,
      introspection_topic,
      payload,
      :dontcare
    )

    control_path = "/some/control/path"
    control_topic = [@realm, @device_id, "control"] ++ String.split(control_path, "/", trim: true)
    payload = "payload"

    Plugin.on_publish(
      :dontcare,
      {:dontcare, @other_mqtt_user},
      :dontcare,
      control_topic,
      payload,
      :dontcare
    )

    path = "/some/data/path"
    interface = "com.my.Interface"
    data_topic = [@realm, @device_id, interface] ++ String.split(path, "/", trim: true)
    payload = "mypayload"

    Plugin.on_publish(
      :dontcare,
      {:dontcare, @other_mqtt_user},
      :dontcare,
      data_topic,
      payload,
      :dontcare
    )

    random_topic = ["random", "topic"]

    Plugin.on_publish(
      :dontcare,
      {:dontcare, @other_mqtt_user},
      :dontcare,
      random_topic,
      "test",
      :dontcare
    )

    refute_receive {:amqp_msg, _payload, _meta}
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

  defp message_id_prefix(realm, device_id, timestamp) do
    realm_trunc = String.slice(realm, 0..63)
    device_id_trunc = String.slice(device_id, 0..15)
    timestamp_hex_str = Integer.to_string(timestamp, 16)
    "#{realm_trunc}-#{device_id_trunc}-#{timestamp_hex_str}-"
  end
end
