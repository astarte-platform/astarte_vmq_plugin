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

defmodule Astarte.VMQ.Plugin.Config do
  @moduledoc """
  This module contains is a central point of configuration for
  Astarte.VMQ.Plugin
  """

  # 1 hour
  @default_device_heartbeat_interval_ms 60 * 60 * 1000

  @doc """
  Load the configuration and transform it if needed (since we are retrieving
  it from Erlang with Cuttlefish, the strings have to be converted to Elixir
  strings
  """
  def init do
    amqp_opts =
      Application.get_env(:astarte_vmq_plugin, :amqp_options, [])
      |> normalize_opts_strings()

    Application.put_env(:astarte_vmq_plugin, :amqp_options, amqp_opts)

    data_queue_prefix =
      Application.get_env(:astarte_vmq_plugin, :data_queue_prefix, "astarte_data_")
      |> to_string()

    Application.put_env(:astarte_vmq_plugin, :data_queue_prefix, data_queue_prefix)

    mirror_queue_name =
      case Application.fetch_env(:astarte_vmq_plugin, :mirror_queue_name) do
        {:ok, charlist_mirror_queue} ->
          to_string(charlist_mirror_queue)

        :error ->
          nil
      end

    Application.put_env(:astarte_vmq_plugin, :mirror_queue_name, mirror_queue_name)

    # Check if we have rpc specific config, if not fall back to :astarte_vmq_plugin :amqp_options)
    astarte_rpc_amqp_opts =
      case Application.fetch_env(:astarte_rpc, :amqp_connection) do
        {:ok, charlist_amqp_opts} ->
          normalize_opts_strings(charlist_amqp_opts)

        :error ->
          amqp_opts
      end

    Application.put_env(:astarte_rpc, :amqp_connection, astarte_rpc_amqp_opts)
  end

  @doc """
  Returns the AMQP connection options
  """
  def amqp_options do
    Application.get_env(:astarte_vmq_plugin, :amqp_options, [])
  end

  @doc """
  Returns the prefix for the AMQP data queues. This is concatenated with
  the queue index to obtain the name of the queue. The range of indexes
  is 0..(data_queue_count - 1)
  """
  def data_queue_prefix do
    Application.get_env(:astarte_vmq_plugin, :data_queue_prefix)
  end

  @doc """
  Returns the number of data queues used for consistent hashing. Defaults to 1.
  """
  def data_queue_count do
    Application.get_env(:astarte_vmq_plugin, :data_queue_count, 1)
  end

  def mirror_queue_name do
    Application.get_env(:astarte_vmq_plugin, :mirror_queue_name)
  end

  def registry_mfa do
    Application.get_env(:astarte_vmq_plugin, :registry_mfa)
  end

  def device_heartbeat_interval_ms do
    Application.get_env(
      :astarte_vmq_plugin,
      :device_heartbeat_interval_ms,
      @default_device_heartbeat_interval_ms
    )
  end

  defp normalize_opts_strings(amqp_options) do
    Enum.map(amqp_options, fn
      {:username, value} -> {:username, to_string(value)}
      {:password, value} -> {:password, to_string(value)}
      {:virtual_host, value} -> {:virtual_host, to_string(value)}
      {:host, value} -> {:host, to_string(value)}
      other -> other
    end)
  end
end
