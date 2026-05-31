# General application configuration
#
# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# It is loaded before any dependency and is restricted to
# this project.
import Config

config :tempest,
  ecto_repos: [Tempest.Repo],
  env: config_env(),
  generators: [timestamp_type: :utc_datetime]

config :tempest, Tempest.Config,
  hostname: "localhost",
  public_url: "http://localhost:4000",
  data_dir: Path.expand("../priv/tempest_dev", __DIR__),
  blob_max_bytes: 10_000_000,
  hosted_did_method: :plc

config :tempest, Tempest.Repo,
  database: Path.expand("../priv/tempest_dev/account.sqlite", __DIR__),
  journal_mode: :wal,
  busy_timeout: 5_000,
  default_transaction_mode: :immediate,
  pool_size: 5

config :tempest, Tempest.Lexicon.Registry, bundled?: true, paths: []

config :tempest, TempestWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: TempestWeb.ErrorHTML, json: TempestWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Tempest.PubSub,
  live_view: [signing_salt: "jgb6xV9v"]

# By default the mailer uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :tempest, Tempest.Mailer, adapter: Swoosh.Adapters.Local

# Note version is required for esbuild
config :esbuild,
  version: "0.25.4",
  tempest: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Note version is required for tailwind
config :tailwind,
  version: "4.1.12",
  tempest: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
