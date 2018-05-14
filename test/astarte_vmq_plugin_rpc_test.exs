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
            qos: 2,
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
            qos: 2,
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
            qos: 42,
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
            qos: 2,
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
