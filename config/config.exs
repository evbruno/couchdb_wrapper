import Config

config :tesla, adapter: Tesla.Adapter.Httpc

if config_env() == :test do
  config :tesla, adapter: Tesla.Mock

  config :logger, :console,
    level: :debug,
    format: "$date $time [$level] $metadata$message\n"
end
