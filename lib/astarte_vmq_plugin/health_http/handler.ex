defmodule Astarte.VMQ.Plugin.HealthHttp.Handler do
  @moduledoc """
  Custom Cowboy handler to add an /healthz endpoint reporting status of
  AMQP connection toward RabbitMQ instance
  """

  def routes do
    [
      {"/healthz", __MODULE__, []}
    ]
  end

  def init(req, state) do
    {status_code, body} =
      case check_amqp_connection_status() do
        :ok ->
          {200, "{AMQP channel status: OK}\n"}

        :error ->
          {503, "{AMQP channel status: DOWN}\n"}
      end

    reply =
      :cowboy_req.reply(
        status_code,
        %{"content-type" => "text/plain"},
        body,
        req
      )

    {:ok, reply, state}
  end

  defp check_amqp_connection_status do
    # retrieve state of underlying Mississippi Events Producer
    %Mississippi.Producer.EventsProducer.State{channel: channel} =
      :sys.get_state(Mississippi.Producer.EventsProducer)

    case channel do
      %AMQP.Channel{} -> :ok
      _ -> :error
    end
  end
end
