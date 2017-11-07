defmodule Astarte.VMQ.Plugin.ConfigTest do
  use ExUnit.Case

  alias Astarte.VMQ.Plugin.Config

  test "config init correctly converts amqp_options to elixir strings" do
    opts =
      [username: 'user',
       password: 'password',
       virtual_host: '/']

    old_opts = Config.amqp_options()

    Application.put_env(:astarte_vmq_plugin, :amqp_options, opts)
    Config.init()

    new_opts = Config.amqp_options()
    assert Keyword.get(new_opts, :username) == "user"
    assert Keyword.get(new_opts, :password) == "password"
    assert Keyword.get(new_opts, :virtual_host) == "/"

    on_exit fn ->
      Application.put_env(:astarte_vmq_plugin, :amqp_options, old_opts)
    end
  end

  test "config init correctly converts queue_name to elixir string" do
    queue_name = 'test_erlang_str'

    old_queue_name = Config.queue_name()

    Application.put_env(:astarte_vmq_plugin, :queue_name, queue_name)
    Config.init()

    assert Config.queue_name() == to_string(queue_name)

    on_exit fn ->
      Application.put_env(:astarte_vmq_plugin, :amqp_options, old_queue_name)
    end
  end
end
