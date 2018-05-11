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

defmodule Astarte.VMQ.Plugin.Config do
  @moduledoc """
  This module contains is a central point of configuration for
  Astarte.VMQ.Plugin
  """

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

    queue_name =
      Application.get_env(:astarte_vmq_plugin, :queue_name, "vmq_all")
      |> to_string()

    Application.put_env(:astarte_vmq_plugin, :queue_name, queue_name)

    mirror_queue_name =
      case Application.fetch_env(:astarte_vmq_plugin, :mirror_queue_name) do
        {:ok, charlist_mirror_queue} ->
          to_string(charlist_mirror_queue)

        :error ->
          nil
      end

    Application.put_env(:astarte_vmq_plugin, :mirror_queue_name, mirror_queue_name)
  end

  @doc """
  Returns the AMQP connection options
  """
  def amqp_options do
    Application.get_env(:astarte_vmq_plugin, :amqp_options, [])
  end

  @doc """
  Returns the name of the queue used by Data Updater Plant
  """
  def queue_name do
    Application.get_env(:astarte_vmq_plugin, :queue_name)
  end

  def mirror_queue_name do
    Application.get_env(:astarte_vmq_plugin, :mirror_queue_name)
  end

  def registry_mfa do
    Application.get_env(:astarte_vmq_plugin, :registry_mfa)
  end

  defp normalize_opts_strings(amqp_options) do
    Enum.map(amqp_options, fn
      {:username, value} -> {:username, to_string(value)}
      {:password, value} -> {:password, to_string(value)}
      {:virtual_host, value} -> {:virtual_host, to_string(value)}
      other -> other
    end)
  end
end
