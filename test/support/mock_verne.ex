defmodule Astarte.VMQ.Plugin.MockVerne do
  def start_link do
    Agent.start_link(fn -> :queue.new() end, name: __MODULE__)
  end

  # Return mock functions for tests instead of the
  # ones returned from :vmq_reg.direct_plugin_exports
  def get_functions do
    empty_fun = fn -> :ok end
    publish_fun = fn topic, payload, opts ->
      Agent.update(__MODULE__, &:queue.in({topic, payload, opts}, &1))
    end

    {empty_fun, publish_fun, {empty_fun, empty_fun}}
  end

  def consume_message do
    Agent.get_and_update(__MODULE__, fn queue ->
      case :queue.out(queue) do
        {{:value, item}, new_queue} ->
          {item, new_queue}

        {:empty, ^queue} ->
          {nil, queue}
      end
    end)
  end
end
