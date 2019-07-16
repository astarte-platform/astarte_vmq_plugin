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

defmodule Astarte.VMQ.Plugin.RPCTest do
  use ExUnit.Case

  alias Astarte.RPC.Protocol.VMQ.Plugin.{
    Call,
    GenericErrorReply,
    GenericOkReply,
    Publish,
    Reply
  }

  alias Astarte.VMQ.Plugin.MockVerne
  alias Astarte.VMQ.Plugin.RPC.Handler

  @topic ["some", "topic"]
  @payload "importantdata"

  setup_all do
    MockVerne.start_link()

    :ok
  end

  test "invalid topic Publish call" do
    serialized_call =
      %Call{
        call: {
          :publish,
          %Publish{
            topic_tokens: [],
            payload: @payload,
            qos: 2
          }
        }
      }
      |> Call.encode()

    assert {:ok, ser_reply} = Handler.handle_rpc(serialized_call)

    assert %Reply{
             reply: {
               :generic_error_reply,
               %GenericErrorReply{error_name: "empty_topic_tokens"}
             }
           } = Reply.decode(ser_reply)

    assert MockVerne.consume_message() == nil
  end

  test "invalid payload Publish call" do
    serialized_call =
      %Call{
        call: {
          :publish,
          %Publish{
            topic_tokens: @topic,
            payload: nil,
            qos: 2
          }
        }
      }
      |> Call.encode()

    assert {:ok, ser_reply} = Handler.handle_rpc(serialized_call)

    assert %Reply{
             reply: {
               :generic_error_reply,
               %GenericErrorReply{error_name: "payload_is_nil"}
             }
           } = Reply.decode(ser_reply)

    assert MockVerne.consume_message() == nil
  end

  test "invalid qos Publish call" do
    serialized_call =
      %Call{
        call: {
          :publish,
          %Publish{
            topic_tokens: @topic,
            payload: @payload,
            qos: 42
          }
        }
      }
      |> Call.encode()

    assert {:ok, ser_reply} = Handler.handle_rpc(serialized_call)

    assert %Reply{
             reply: {
               :generic_error_reply,
               %GenericErrorReply{error_name: "invalid_qos"}
             }
           } = Reply.decode(ser_reply)

    assert MockVerne.consume_message() == nil
  end

  test "valid Publish call" do
    serialized_call =
      %Call{
        call: {
          :publish,
          %Publish{
            topic_tokens: @topic,
            payload: @payload,
            qos: 2
          }
        }
      }
      |> Call.encode()

    assert {:ok, ser_reply} = Handler.handle_rpc(serialized_call)

    assert %Reply{
             reply: {
               :generic_ok_reply,
               %GenericOkReply{}
             }
           } = Reply.decode(ser_reply)

    assert MockVerne.consume_message() == {@topic, @payload, %{qos: 2}}
  end
end
