#
# Copyright (C) 2017 Ispirata Srl
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
