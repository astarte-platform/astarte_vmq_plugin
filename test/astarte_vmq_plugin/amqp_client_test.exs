defmodule Astarte.VMQ.Plugin.AMQPClientTest do
  use ExUnit.Case

  alias Astarte.VMQ.Plugin.AMQPClient

  test "amqp_client recovers from channel crash" do
    pid = Process.whereis(AMQPClient)

    chan = :sys.get_state(pid)

    Process.exit(chan.pid, :disconnected)

    :timer.sleep(1000)

    new_chan = :sys.get_state(pid)

    assert chan != new_chan
    assert Process.alive?(new_chan.pid)
  end

  test "amqp_client recovers from conn crash" do
    pid = Process.whereis(AMQPClient)

    chan = :sys.get_state(pid)

    Process.exit(chan.conn.pid, :disconnected)

    :timer.sleep(1000)

    new_chan = :sys.get_state(pid)

    assert chan != new_chan
    assert Process.alive?(new_chan.conn.pid)
  end

end
