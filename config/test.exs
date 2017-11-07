use Mix.Config

config :astarte_vmq_plugin, :amqp_options,
  host: "rabbitmq"

config :astarte_vmq_plugin, :queue_name,
  "test_queue"
