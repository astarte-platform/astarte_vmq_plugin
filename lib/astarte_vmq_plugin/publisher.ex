defmodule Astarte.VMQ.Plugin.Publisher do
  use GenServer

  # API

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  # Callbacks

  def init([registry_mfa]) do
    {module, fun, args} = registry_mfa
    {register_fun, publish_fun, _sub_and_unsub_fun} = apply(module, fun, args)
    true = is_function(register_fun, 0)
    true = is_function(publish_fun, 3)
    :ok = register_fun.()
    {:ok, %{publish_fun: publish_fun}}
  end
end
