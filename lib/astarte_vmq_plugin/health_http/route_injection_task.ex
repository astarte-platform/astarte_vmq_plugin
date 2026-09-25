defmodule Astarte.VMQ.Plugin.HealthHttp.RouteInjectionTask do
  @moduledoc """
  Task for injection of custom Cowboy HTTP handlers at VerneMQ startup.
  """

  use Task, restart: :transient

  @http_handler_module Astarte.VMQ.Plugin.HealthHttp.Handler
  @http_metrics_port 8888

  def start_link(_arg) do
    Task.start_link(__MODULE__, :inject_custom_routes, [])
  end

  def inject_custom_routes() do
    Code.ensure_loaded!(@http_handler_module)
    custom_routes = @http_handler_module.routes()

    [{:_, [], custom_paths}] = :cowboy_router.compile([{:_, custom_routes}])

    listener_ref =
      Enum.find_value(:ranch.info(), fn {ref, details} ->
        if Map.get(details, :port) == @http_metrics_port, do: ref, else: nil
      end)

    # live Cowboy configuration
    opts = :ranch.get_protocol_options(listener_ref)
    env = Map.get(opts, :env, %{})
    existing_dispatch = Map.get(env, :dispatch, [])

    # merge new compiled paths into the existing paths
    new_dispatch =
      Enum.map(existing_dispatch, fn {host, constraints, paths} ->
        {host, constraints, paths ++ custom_paths}
      end)

    # apply the updated routing table to the live server
    new_env = Map.put(env, :dispatch, new_dispatch)
    new_opts = Map.put(opts, :env, new_env)
    :ranch.set_protocol_options(listener_ref, new_opts)
  end
end
