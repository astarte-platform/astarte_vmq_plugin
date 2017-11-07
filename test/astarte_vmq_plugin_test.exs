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

  setup_all do
    amqp_opts = Config.amqp_options()
    {:ok, conn} = Connection.open(amqp_opts)
    {:ok, chan} = Channel.open(conn)
    Queue.declare(chan, Config.queue_name())
    Queue.subscribe(chan, Config.queue_name(), fn payload, meta ->
      send(self(), {payload, meta})
    end)
    :ok
  end

  test "auth_on_register for a device" do
    assert {:ok, modifiers} = Plugin.auth_on_register(:dontcare, {"/", :dontcare}, @device_base_path, :dontcare, :dontcare)
    assert Keyword.get(modifiers, :subscriber_id) == {"/", @device_base_path}
  end

  test "auth_on_register for non-devices" do
    assert :next = Plugin.auth_on_register(:dontcare, {"/", :dontcare}, @other_mqtt_user, :dontcare, :dontcare)
  end

  test "partially authorized auth_on_subscribe for devices" do
    authorized_topics =
      [{[@realm, @device_id, "authorizedtopic"], 2},
       {[@realm, @device_id, "otherauthorizedtopic"], 1}]


    unauthorized_topics =
      [{[@realm, @other_device_id, "unauthorizedtopic"], 0},
       {["other_realm", @device_id, "unauthorizedtopic"], 1},
       {["unauthorizedtopic"], 2}]

    topics = unauthorized_topics ++ authorized_topics

    assert {:ok, ^authorized_topics} = Plugin.auth_on_subscribe(:dontcare, {:dontcare, @device_base_path}, topics)
  end

  test "fully authorized auth_on_subscribe for devices" do
    topics =
      [{[@realm, @device_id, "authorizedtopic"], 2},
       {[@realm, @device_id, "otherauthorizedtopic"], 1}]

    assert {:ok, ^topics} = Plugin.auth_on_subscribe(:dontcare, {:dontcare, @device_base_path}, topics)
  end

  test "not authorized auth_on_subscribe for devices" do
    unauthorized_topics =
      [{[@realm, @other_device_id, "unauthorizedtopic"], 0},
       {["other_realm", @device_id, "unauthorizedtopic"], 1},
       {["unauthorizedtopic"], 2}]

    assert {:error, :unauthorized} = Plugin.auth_on_subscribe(:dontcare, {:dontcare, @device_base_path}, unauthorized_topics)
  end

  test "auth_on_subscribe for non-devices" do
    topics =
      [{["some", "random", "topic"], 1},
       {["another", "random", "topic"], 0},
       {["and", "so", "on"], 2}]

    assert :ok = Plugin.auth_on_subscribe(:dontcare, {:dontcare, @other_mqtt_user}, topics)
  end

  test "authorized auth_on_publish for device" do
    introspection_topic = [@realm, @device_id]
    data_topic = [@realm, @device_id, "com.some.Interface", "some", "path"]
    control_topic = [@realm, @device_id, "control", "some", "path"]

    assert :ok = Plugin.auth_on_publish(:dontcare, {:dontcare, @device_base_path}, :dontcare, introspection_topic, :dontcare, :dontcare)
    assert :ok = Plugin.auth_on_publish(:dontcare, {:dontcare, @device_base_path}, :dontcare, data_topic, :dontcare, :dontcare)
    assert :ok = Plugin.auth_on_publish(:dontcare, {:dontcare, @device_base_path}, :dontcare, control_topic, :dontcare, :dontcare)
  end

  test "unauthorized auth_on_publish for device" do
    other_device_topic = [@realm, @other_device_id, "com.some.Interface", "some", "path"]
    other_realm_topic = ["other_realm", @device_id, "com.some.Interface", "some", "path"]
    out_of_hierarchy_topic = ["some", "topic"]

    assert {:error, :unauthorized} =
      Plugin.auth_on_publish(:dontcare, {:dontcare, @device_base_path}, :dontcare, other_device_topic, :dontcare, :dontcare)
    assert {:error, :unauthorized} =
      Plugin.auth_on_publish(:dontcare, {:dontcare, @device_base_path}, :dontcare, other_realm_topic, :dontcare, :dontcare)
    assert {:error, :unauthorized} =
      Plugin.auth_on_publish(:dontcare, {:dontcare, @device_base_path}, :dontcare, out_of_hierarchy_topic, :dontcare, :dontcare)
  end

  test "authorized auth_on_publish for non-device" do
    introspection_topic = [@realm, @device_id]
    data_topic = [@realm, @device_id, "com.some.Interface", "some", "path"]
    control_topic = [@realm, @device_id, "control", "some", "path"]
    random_topic = ["any", "topic"]

    assert :ok = Plugin.auth_on_publish(:dontcare, {:dontcare, @other_mqtt_user}, :dontcare, introspection_topic, :dontcare, :dontcare)
    assert :ok = Plugin.auth_on_publish(:dontcare, {:dontcare, @other_mqtt_user}, :dontcare, data_topic, :dontcare, :dontcare)
    assert :ok = Plugin.auth_on_publish(:dontcare, {:dontcare, @other_mqtt_user}, :dontcare, control_topic, :dontcare, :dontcare)
    assert :ok = Plugin.auth_on_publish(:dontcare, {:dontcare, @other_mqtt_user}, :dontcare, random_topic, :dontcare, :dontcare)
  end
end
