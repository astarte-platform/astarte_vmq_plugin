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

defmodule Astarte.VMQ.Plugin.ConfigTest do
  use ExUnit.Case

  alias Astarte.VMQ.Plugin.Config

  test "config init correctly converts amqp_options to elixir strings" do
    opts = [username: 'user', password: 'password', virtual_host: '/']

    old_opts = Config.amqp_options()

    Application.put_env(:astarte_vmq_plugin, :amqp_options, opts)
    Config.init()

    new_opts = Config.amqp_options()
    assert Keyword.get(new_opts, :username) == "user"
    assert Keyword.get(new_opts, :password) == "password"
    assert Keyword.get(new_opts, :virtual_host) == "/"

    on_exit(fn ->
      Application.put_env(:astarte_vmq_plugin, :amqp_options, old_opts)
    end)
  end

  test "config init correctly converts queue_name to elixir string" do
    queue_name = 'test_erlang_str'

    old_queue_name = Config.queue_name()

    Application.put_env(:astarte_vmq_plugin, :queue_name, queue_name)
    Config.init()

    assert Config.queue_name() == to_string(queue_name)

    on_exit(fn ->
      Application.put_env(:astarte_vmq_plugin, :amqp_options, old_queue_name)
    end)
  end
end
