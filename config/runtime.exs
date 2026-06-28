import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/tempest start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :tempest, TempestWeb.Endpoint, server: true
end

config :tempest, TempestWeb.Endpoint, http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if hostname = System.get_env("TEMPEST_HOSTNAME") do
  config :tempest, Tempest.Config, hostname: hostname
end

if public_url = System.get_env("TEMPEST_PUBLIC_URL") do
  config :tempest, Tempest.Config, public_url: public_url
end

if data_dir = System.get_env("TEMPEST_DATA_DIR") do
  config :tempest, Tempest.Config, data_dir: data_dir
end

if blob_max_bytes = System.get_env("TEMPEST_BLOB_MAX_BYTES") do
  config :tempest, Tempest.Config, blob_max_bytes: String.to_integer(blob_max_bytes)
end

if hosted_did_method = System.get_env("TEMPEST_HOSTED_DID_METHOD") do
  config :tempest, Tempest.Config, hosted_did_method: String.to_existing_atom(hosted_did_method)
end

if admin_did = System.get_env("TEMPEST_ADMIN_DID") do
  config :tempest, Tempest.Config, admin_did: admin_did
end

identity_runtime_config = []

identity_runtime_config =
  if plc_rotation_key = System.get_env("TEMPEST_PLC_ROTATION_KEY") do
    Keyword.put(identity_runtime_config, :plc_rotation_key, plc_rotation_key)
  else
    identity_runtime_config
  end

identity_runtime_config =
  if plc_recovery_key = System.get_env("TEMPEST_PLC_RECOVERY_KEY") do
    Keyword.put(identity_runtime_config, :plc_recovery_key, plc_recovery_key)
  else
    identity_runtime_config
  end

if identity_runtime_config != [] do
  config :tempest, Tempest.Identity, identity_runtime_config
end

if blob_cdn_base_url = System.get_env("TEMPEST_BLOB_CDN_BASE_URL") do
  config :tempest, Tempest.Blobs, cdn_base_url: blob_cdn_base_url
end

if crawlers = System.get_env("TEMPEST_CRAWLERS") do
  relays = String.split(crawlers, ",", trim: true) |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
  config :tempest, Tempest.Sync, relays: relays
end

if System.get_env("TEMPEST_BLOB_STORE") == "s3" do
  s3_headers =
    case System.get_env("TEMPEST_BLOB_S3_AUTHORIZATION") do
      nil -> []
      value -> [{"authorization", value}]
    end

  blob_s3_config =
    [
      endpoint_url: System.fetch_env!("TEMPEST_BLOB_S3_ENDPOINT"),
      bucket: System.fetch_env!("TEMPEST_BLOB_S3_BUCKET"),
      region: System.get_env("TEMPEST_BLOB_S3_REGION", "auto"),
      access_key_id: System.get_env("TEMPEST_BLOB_S3_ACCESS_KEY_ID"),
      secret_access_key: System.get_env("TEMPEST_BLOB_S3_SECRET_ACCESS_KEY"),
      headers: s3_headers
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)

  config :tempest, Tempest.Blobs,
    storage_adapter: Tempest.Blobs.S3Storage,
    storage_config: blob_s3_config
end

if System.get_env("TEMPEST_BACKUP_STORE") == "s3" do
  s3_headers =
    case System.get_env("TEMPEST_BACKUP_S3_AUTHORIZATION") do
      nil -> []
      value -> [{"authorization", value}]
    end

  backup_s3_config =
    [
      endpoint_url: System.fetch_env!("TEMPEST_BACKUP_S3_ENDPOINT"),
      bucket: System.fetch_env!("TEMPEST_BACKUP_S3_BUCKET"),
      region: System.get_env("TEMPEST_BACKUP_S3_REGION", "auto"),
      access_key_id: System.get_env("TEMPEST_BACKUP_S3_ACCESS_KEY_ID"),
      secret_access_key: System.get_env("TEMPEST_BACKUP_S3_SECRET_ACCESS_KEY"),
      headers: s3_headers
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)

  config :tempest, Tempest.Admin.Backup,
    store: :s3,
    s3: backup_s3_config
end

# Email provider selection. The default stays `local` (set in config/dev.exs
# and config/test.exs) unless an operator opts into `smtp` or `resend`.
#
# `resolve/2` only reconfigures the mailer when a real provider is selected, so
# the Swoosh.Adapters.Test / Swoosh.Adapters.Local defaults set by the
# environment config files are preserved when `TEMPEST_EMAIL_PROVIDER` is unset
# and the legacy `TEMPEST_SMTP_ENABLED` flag is not set.
email_provider_config =
  Tempest.Security.EmailConfig.resolve(System.get_env(), env: config_env())

if email_provider_config.provider != :local do
  config :tempest, Tempest.Mailer, email_provider_config.mailer_config
  config :tempest, Tempest.Security.Email, email_provider_config.email_config
end

if admin_token_hash = System.get_env("TEMPEST_ADMIN_TOKEN_HASH") do
  config :tempest, :admin_token_hash, admin_token_hash
end

if appview_url = System.get_env("TEMPEST_APPVIEW_URL") do
  config :tempest, Tempest.Xrpc.Proxy, upstream_base_url: String.trim_trailing(appview_url, "/")
end

lexicon_runtime_config = []

lexicon_runtime_config =
  if lexicon_paths = System.get_env("TEMPEST_LEXICON_PATHS") do
    Keyword.put(lexicon_runtime_config, :paths, String.split(lexicon_paths, ",", trim: true))
  else
    lexicon_runtime_config
  end

lexicon_runtime_config =
  if known_records = System.get_env("TEMPEST_LEXICON_KNOWN_RECORDS") do
    Keyword.put(lexicon_runtime_config, :known_records, String.split(known_records, ",", trim: true))
  else
    lexicon_runtime_config
  end

lexicon_runtime_config =
  if System.get_env("TEMPEST_LEXICON_EXTERNAL_RESOLVER") in ["1", "true", "TRUE"] do
    Keyword.put(lexicon_runtime_config, :external_resolver, enabled?: true)
  else
    lexicon_runtime_config
  end

if lexicon_runtime_config != [] do
  config :tempest, Tempest.Lexicon.Registry, lexicon_runtime_config
end

if config_env() == :prod do
  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host =
    System.get_env("TEMPEST_HOSTNAME") ||
      System.get_env("PHX_HOST") ||
      raise """
      environment variable TEMPEST_HOSTNAME is missing.
      For example: tempest.example.com
      """

  public_url = System.get_env("TEMPEST_PUBLIC_URL") || "https://#{host}"
  data_dir = System.get_env("TEMPEST_DATA_DIR") || "/var/lib/tempest"

  config :tempest, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :tempest, Tempest.Config,
    hostname: host,
    public_url: public_url,
    data_dir: data_dir

  config :tempest, Tempest.Repo,
    database: Path.join(data_dir, "account.sqlite"),
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5")

  config :tempest, TempestWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :tempest, TempestWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :tempest, TempestWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Here is an example configuration for Mailgun:
  #
  #     config :tempest, Tempest.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # Most non-SMTP adapters require an API client. Swoosh supports Req, Hackney,
  # and Finch out-of-the-box. This configuration is typically done at
  # compile-time in your config/prod.exs:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Req
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
