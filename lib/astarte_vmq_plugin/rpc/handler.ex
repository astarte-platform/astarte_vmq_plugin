#
# Copyright (C) 2018 Ispirata Srl
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

defmodule Astarte.VMQ.Plugin.RPC.Handler do
  @behaviour Astarte.RPC.Handler

  alias Astarte.RPC.Protocol.VMQ.Plugin.{
    Call,
    Disconnect,
    GenericErrorReply,
    GenericOkReply,
    Publish,
    Reply
  }
  alias Astarte.VMQ.Plugin.Publisher

  require Logger

  def handle_rpc(payload) do
    with {:ok, call_tuple} <- extract_call_tuple(Call.decode(payload)) do
      call_rpc(call_tuple)
    end
  end

  defp extract_call_tuple(%Call{call: nil}) do
    Logger.warn("Received empty call")
    {:error, :empty_call}
  end

  defp extract_call_tuple(%Call{call: call_tuple}) do
    {:ok, call_tuple}
  end

  defp call_rpc({:disconnect, %Disconnect{client_id: nil}}) do
    Logger.warn("Disconnect with nil client_id")
    generic_error(:client_id_is_nil, "client_id is nil")
  end

  defp call_rpc({:disconnect, %Disconnect{discard_state: nil}}) do
    Logger.warn("Disconnect with nil discard_state")
    generic_error(:discard_state_is_nil, "discard_state is nil")
  end

  defp call_rpc({:disconnect, %Disconnect{client_id: client_id, discard_state: discard_state}}) do
    # TODO: implement disconnect
    Logger.log(
      "Disconnect client_id: #{inspect(client_id)} discard_state: #{inspect(discard_state)}"
    )

    generic_ok()
  end

  defp call_rpc({:publish, %Publish{topic_tokens: []}}) do
    Logger.warn("Publish with empty topic_tokens")
    generic_error(:empty_topic_tokens, "empty topic tokens")
  end

  defp call_rpc({:publish, %Publish{payload: nil}}) do
    Logger.warn("Publish with nil payload")
    generic_error(:payload_is_nil, "payload is nil")
  end

  # This also handles the case of qos == nil, that is > 2
  defp call_rpc({:publish, %Publish{qos: qos}}) when qos > 2 or qos < 0 do
    Logger.warn("Publish with invalid QoS")
    generic_error(:invalid_qos, "invalid QoS")
  end

  defp call_rpc({:publish, %Publish{topic_tokens: topic_tokens, payload: payload, qos: qos}}) do
    case Publisher.publish(topic_tokens, payload, qos) do
      :ok ->
        generic_ok()

      {:error, reason} ->
        Logger.warn("Publish failed with reason: #{inspect reason}")
        generic_error(reason)

      other_err ->
        Logger.warn("Unknown error in publish: #{inspect other_err}")
        generic_error(:publish_error, "error during publish")
    end
  end

  defp generic_error(
         error_name,
         user_readable_message \\ nil,
         user_readable_error_name \\ nil,
         error_data \\ nil
       ) do
    %GenericErrorReply{
      error_name: to_string(error_name),
      user_readable_message: user_readable_message,
      user_readable_error_name: user_readable_error_name,
      error_data: error_data
    }
    |> encode_reply(:generic_error_reply)
    |> ok_wrap
  end

  defp generic_ok do
    %GenericOkReply{}
    |> encode_reply(:generic_ok_reply)
    |> ok_wrap
  end

  defp encode_reply(reply, reply_type) do
    %Reply{reply: {reply_type, reply}}
    |> Reply.encode()
  end

  defp ok_wrap(result) do
    {:ok, result}
  end
end
