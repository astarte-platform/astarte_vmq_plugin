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
  end

  @doc """
  Returns the AMQP connection options
  """
  def amqp_options do
    Application.get_env(:astarte_vmq_plugin, :amqp_options, [])
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
