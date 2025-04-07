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

  alias Astarte.VMQ.Plugin.MockVerne

  @topic ["some", "topic"]
  @payload "importantdata"

  setup_all do
    MockVerne.start_link()

    %{
      rpc_server: {:via, Horde.Registry, {Registry.VMQPluginRPC, :server}}
    }
  end

  test "invalid topic Publish call", %{rpc_server: server} do
    data =
      %{
        topic_tokens: [],
        payload: @payload,
        qos: 2
      }

    assert {:error, :empty_topic_tokens} = GenServer.call(server, {:publish, data})

    assert MockVerne.consume_message() == nil
  end

  test "invalid qos Publish call", %{rpc_server: server} do
    data =
      %{
        topic_tokens: @topic,
        payload: @payload,
        qos: 42
      }

    assert {:error, :invalid_qos} = GenServer.call(server, {:publish, data})

    assert MockVerne.consume_message() == nil
  end

  test "valid Publish call", %{rpc_server: server} do
    data =
      %{
        topic_tokens: @topic,
        payload: @payload,
        qos: 2
      }

    assert {:ok, _} = GenServer.call(server, {:publish, data})

    assert MockVerne.consume_message() == {@topic, @payload, %{qos: 2}}
  end
end
