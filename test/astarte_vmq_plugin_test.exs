defmodule Astarte.VMQ.PluginTest do
  use ExUnit.Case
  doctest Astarte.VMQ.Plugin

  test "greets the world" do
    assert Astarte.VMQ.Plugin.hello() == :world
  end
end
