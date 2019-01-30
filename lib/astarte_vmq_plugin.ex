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

defmodule Astarte.VMQ.Plugin do
  @moduledoc """
  Documentation for Astarte.VMQ.Plugin.
  """

  alias Astarte.VMQ.Plugin.AMQPClient

  @max_rand trunc(:math.pow(2, 32) - 1)

  def auth_on_register(_peer, _subscriber_id, :undefined, _password, _cleansession) do
    # If it doesn't have a username we let someone else decide
    :next
  end

  def auth_on_register(_peer, {mountpoint, _client_id}, username, _password, _cleansession) do
    if !String.contains?(username, "/") do
      # Not a device, let someone else decide
      :next
    else
      subscriber_id = {mountpoint, username}
      # TODO: we probably want some of these values to be configurable in some way
      {:ok,
       [
         subscriber_id: subscriber_id,
         max_inflight_messages: 100,
         max_message_rate: 10000,
         max_message_size: 65535,
         retry_interval: 20000,
         upgrade_qos: false
       ]}
    end
  end

  def auth_on_publish(
        _username,
        {_mountpoint, client_id},
        _qos,
        topic_tokens,
        _payload,
        _isretain
      ) do
    cond do
      # Not a device, authorizing everything
      !String.contains?(client_id, "/") ->
        :ok

      # Device auth
      String.split(client_id, "/") == Enum.take(topic_tokens, 2) ->
        :ok

      true ->
        {:error, :unauthorized}
    end
  end

  def auth_on_subscribe(_username, {_mountpoint, client_id}, topics) do
    if !String.contains?(client_id, "/") do
      :ok
    else
      client_id_tokens = String.split(client_id, "/")

      authorized_topics =
        Enum.filter(topics, fn {topic_tokens, _qos} ->
          client_id_tokens == Enum.take(topic_tokens, 2)
        end)

      case authorized_topics do
        [] -> {:error, :unauthorized}
        authorized_topics -> {:ok, authorized_topics}
      end
    end
  end

  def disconnect_client(client_id, discard_state) do
    opts =
      if discard_state do
        [:do_cleanup]
      else
        []
      end

    mountpoint = ''
    subscriber_id = {mountpoint, client_id}

    case :vernemq_dev_api.disconnect_by_subscriber_id(subscriber_id, opts) do
      :ok ->
        :ok

      :not_found ->
        {:error, :not_found}
    end
  end

  def on_client_gone({_mountpoint, client_id}) do
    publish_event(client_id, "disconnection", now_us_x10_timestamp())
  end

  def on_client_offline({_mountpoint, client_id}) do
    publish_event(client_id, "disconnection", now_us_x10_timestamp())
  end

  def on_register({ip_addr, _port}, {_mountpoint, client_id}, _username) do
    timestamp = now_us_x10_timestamp()

    ip_string =
      ip_addr
      |> :inet.ntoa()
      |> to_string()

    publish_event(client_id, "connection", timestamp, x_astarte_remote_ip: ip_string)
  end

  def on_publish(_username, {_mountpoint, client_id}, _qos, topic_tokens, payload, _isretain) do
    with [realm, device_id] <- String.split(client_id, "/") do
      timestamp = now_us_x10_timestamp()

      case topic_tokens do
        [^realm, ^device_id] ->
          publish_introspection(realm, device_id, payload, timestamp)

        [^realm, ^device_id, "control" | control_path_tokens] ->
          control_path = "/" <> Enum.join(control_path_tokens, "/")
          publish_control_message(realm, device_id, control_path, payload, timestamp)

        [^realm, ^device_id, interface | path_tokens] ->
          path = "/" <> Enum.join(path_tokens, "/")
          publish_data(realm, device_id, interface, path, payload, timestamp)
      end
    else
      # Not a device, ignoring it
      _ ->
        :ok
    end
  end

  defp publish_introspection(realm, device_id, payload, timestamp) do
    publish(realm, device_id, payload, "introspection", timestamp)
  end

  defp publish_data(realm, device_id, interface, path, payload, timestamp) do
    additional_headers = [x_astarte_interface: interface, x_astarte_path: path]

    publish(realm, device_id, payload, "data", timestamp, additional_headers)
  end

  defp publish_control_message(realm, device_id, control_path, payload, timestamp) do
    additional_headers = [x_astarte_control_path: control_path]

    publish(realm, device_id, payload, "control", timestamp, additional_headers)
  end

  defp publish_event(client_id, event_string, timestamp, additional_headers \\ []) do
    with [realm, device_id] <- String.split(client_id, "/") do
      publish(realm, device_id, "", event_string, timestamp, additional_headers)
    else
      # Not a device, ignoring it
      _ ->
        :ok
    end
  end

  defp publish(realm, device_id, payload, event_string, timestamp, additional_headers \\ []) do
    headers =
      [
        x_astarte_vmqamqp_proto_ver: 1,
        x_astarte_realm: realm,
        x_astarte_device_id: device_id,
        x_astarte_msg_type: event_string
      ] ++ additional_headers

    message_id = generate_message_id(realm, device_id, timestamp)

    :ok = AMQPClient.publish(payload, headers: headers, message_id: message_id, timestamp: timestamp)
  end

  defp now_us_x10_timestamp do
    DateTime.utc_now()
    |> DateTime.to_unix(:microseconds)
    |> Kernel.*(10)
  end

  defp generate_message_id(realm, device_id, timestamp) do
    realm_trunc = String.slice(realm, 0..63)
    device_id_trunc = String.slice(device_id, 0..15)
    timestamp_hex_str = Integer.to_string(timestamp, 16)
    rnd = Enum.random(0..@max_rand) |> Integer.to_string(16)

    "#{realm_trunc}-#{device_id_trunc}-#{timestamp_hex_str}-#{rnd}"
  end
end
