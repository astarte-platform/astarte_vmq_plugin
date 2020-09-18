#
# This file is part of Astarte.
#
# Copyright 2018 Ispirata Srl
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

defmodule Astarte.VMQ.Plugin.RPC.Handler do
  @behaviour Astarte.RPC.Handler

  alias Astarte.RPC.Protocol.VMQ.Plugin.{
    Call,
    Disconnect,
    GenericErrorReply,
    GenericOkReply,
    Publish,
    PublishReply,
    Reply
  }

  alias Astarte.VMQ.Plugin.Publisher
  alias Astarte.VMQ.Plugin

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

  defp call_rpc({:disconnect, %Disconnect{client_id: ""}}) do
    Logger.warn("Disconnect with empty client_id")
    generic_error(:client_id_is_empty, "client_id is \"\"")
  end

  defp call_rpc({:disconnect, %Disconnect{discard_state: ""}}) do
    Logger.warn("Disconnect with empty discard_state")
    generic_error(:discard_state_is_empty, "discard_state is \"\"")
  end

  defp call_rpc({:disconnect, %Disconnect{client_id: client_id, discard_state: discard_state}}) do
    case Plugin.disconnect_client(client_id, discard_state) do
      :ok ->
        generic_ok()

      {:error, reason} ->
        generic_error(reason)
    end
  end

  defp call_rpc({:publish, %Publish{topic_tokens: []}}) do
    Logger.warn("Publish with empty topic_tokens")
    generic_error(:empty_topic_tokens, "empty topic tokens")
  end

  # This also handles the case of qos == nil, that is > 2
  defp call_rpc({:publish, %Publish{qos: qos}}) when qos > 2 or qos < 0 do
    Logger.warn("Publish with invalid QoS")
    generic_error(:invalid_qos, "invalid QoS")
  end

  defp call_rpc({:publish, %Publish{topic_tokens: topic_tokens, payload: payload, qos: qos}}) do
    case Publisher.publish(topic_tokens, payload, qos) do
      {:ok, {local_matches, remote_matches}} ->
        publish_reply(local_matches, remote_matches)

      {:error, reason} ->
        Logger.warn("Publish failed with reason: #{inspect(reason)}")
        generic_error(reason)

      other_err ->
        Logger.warn("Unknown error in publish: #{inspect(other_err)}")
        generic_error(:publish_error, "error during publish")
    end
  end

  defp generic_error(
         error_name,
         user_readable_message \\ "",
         user_readable_error_name \\ "",
         error_data \\ ""
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

  defp publish_reply(local_matches, remote_matches) do
    %PublishReply{local_matches: local_matches, remote_matches: remote_matches}
    |> encode_reply(:publish_reply)
    |> ok_wrap
  end

  defp encode_reply(%GenericOkReply{} = reply, _reply_type) do
    %Reply{reply: {:generic_ok_reply, reply}, error: false}
    |> Reply.encode()
  end

  defp encode_reply(%GenericErrorReply{} = reply, _reply_type) do
    %Reply{reply: {:generic_error_reply, reply}, error: true}
    |> Reply.encode()
  end

  defp encode_reply(reply, reply_type) do
    %Reply{reply: {reply_type, reply}, error: false}
    |> Reply.encode()
  end

  defp ok_wrap(result) do
    {:ok, result}
  end
end
