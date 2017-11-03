defmodule Astarte.VMQ.Plugin do
  @moduledoc """
  Documentation for Astarte.VMQ.Plugin.
  """

  def auth_on_register(_peer, {mountpoint, _client_id}, username, _password, _cleansession) do
    if !String.contains?(username, "/") do
      # Not a device, let someone else decide
      :next
    else
      subscriber_id = {mountpoint, username}
      #TODO: we probably want some of these values to be configurable in some way
      {:ok,
        [subscriber_id: subscriber_id,
         max_inflight_messages: 100,
         max_message_rate: 10000,
         max_message_size: 65535,
         retry_interval: 20000,
         upgrade_qos: false]}
    end
  end

  def auth_on_publish(_username, {_mountpoint, client_id}, _qos, topic, _payload, _isretain) do
    cond do
      # Not a device, authorizing everything
      !String.contains?(client_id, "/") ->
        :ok
        # Topic is a single string
      is_binary(topic) ->
        {:error, :unauthorized}
        # Device auth
      String.split(client_id, "/") == Enum.take(topic, 2) ->
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
        Enum.filter(topics, fn {topic_path, _qos} ->
          if is_binary(topic_path) do
            false
          else
            client_id_tokens == Enum.take(topic_path, 2)
          end
        end)

      case authorized_topics do
        [] -> {:error, :unauthorized}
        authorized_topics -> {:ok, authorized_topics}
      end
    end
  end
end
