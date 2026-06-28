defmodule Tempest.Security.EmailConfig do
  @moduledoc """
  Email provider configuration for security flows.

  Resolves a `TEMPEST_EMAIL_PROVIDER` selection into a Swoosh mailer
  configuration and a shared `from` name/address pair. Kept separate from
  `config/runtime.exs` so the selection, normalization, and fail-closed logic
  can be exercised without booting the full application.

  Supported providers:

    * `local`  - `Swoosh.Adapters.Local` (dev/test default; never fail-closed)
    * `smtp`   - `Swoosh.Adapters.SMTP`
    * `resend` - `Swoosh.Adapters.Resend`

  Fail-closed behavior is opt-in via the `:env` option. Production boots are
  the only context that raise; non-prod environments fall back to `local` when
  credentials are missing so tests and dev never block on email config.

  `resolve/2` is pure: it reads exclusively from the passed environment map.
  `config/runtime.exs` passes `System.get_env/0` at boot; tests pass a literal
  map so the resolution and fail-closed logic can be exercised without setting
  real environment variables.
  """

  @default_provider :local
  @default_from_name "Tempest"
  @default_from_address "noreply@localhost"

  @providers ~w(local smtp resend)a

  @typedoc """
  Resolved email provider configuration.

  `mailer_config` is suitable for `config :tempest, Tempest.Mailer, ...`.
  `email_config` is suitable for `config :tempest, Tempest.Security.Email, ...`.
  """
  defstruct provider: @default_provider,
            mailer_config: [adapter: Swoosh.Adapters.Local],
            email_config: [from_name: @default_from_name, from_address: @default_from_address]

  @type t :: %__MODULE__{
          provider: atom(),
          mailer_config: keyword(),
          email_config: keyword()
        }

  @doc """
  Resolve provider configuration from an environment map.

  Options:

    * `:env` - the `config_env()` of the booting application. When `:prod`,
      `smtp`/`resend` fail closed on missing credentials or from address.

  ## Backwards compatibility

  A truthy `TEMPEST_SMTP_ENABLED` selects `smtp` when
  `TEMPEST_EMAIL_PROVIDER` is not set. The older `TEMPEST_SMTP_FROM_NAME` and
  `TEMPEST_SMTP_FROM_ADDRESS` variables remain honored as aliases for the
  shared `TEMPEST_EMAIL_FROM_*` names.

  When no provider is selected, the environment keeps `local` (the dev/test
  default set in `config/dev.exs` and `config/test.exs`). Production with no
  provider also keeps `local` rather than raising: an operator who wants real
  delivery must opt in by setting `TEMPEST_EMAIL_PROVIDER`.
  """
  @spec resolve(map(), keyword()) :: t()
  def resolve(env, opts \\ []) do
    provider = resolve_provider(env)
    boot_env = Keyword.get(opts, :env, config_env())

    from_name = from_name(env)
    from_address = from_address(env)

    mailer_config = build_mailer_config(provider, env, boot_env, from_address)
    email_config = [from_name: from_name, from_address: from_address]

    %__MODULE__{
      provider: provider,
      mailer_config: mailer_config,
      email_config: email_config
    }
  end

  defp resolve_provider(env) do
    case env["TEMPEST_EMAIL_PROVIDER"] do
      nil ->
        if smtp_enabled?(env), do: :smtp, else: @default_provider

      value ->
        atom = String.to_existing_atom(value)
        validate_provider!(atom)
        atom
    end
  end

  defp validate_provider!(provider) when provider in @providers, do: :ok

  defp validate_provider!(provider) do
    raise ArgumentError,
          "invalid TEMPEST_EMAIL_PROVIDER #{inspect(provider)}; expected one of local, smtp, resend"
  end

  defp smtp_enabled?(env) do
    env["TEMPEST_SMTP_ENABLED"] in ["1", "true", "TRUE"]
  end

  defp from_name(env) do
    env["TEMPEST_EMAIL_FROM_NAME"] || env["TEMPEST_SMTP_FROM_NAME"] || @default_from_name
  end

  defp from_address(env) do
    env["TEMPEST_EMAIL_FROM_ADDRESS"] || env["TEMPEST_SMTP_FROM_ADDRESS"]
  end

  defp build_mailer_config(:local, _env, _boot_env, _from_address) do
    [adapter: Swoosh.Adapters.Local]
  end

  defp build_mailer_config(:smtp, env, boot_env, from_address) do
    require_from_address!(boot_env, from_address, :smtp)

    [
      adapter: Swoosh.Adapters.SMTP,
      relay: require_env!(env, "TEMPEST_SMTP_HOST", boot_env),
      port: env["TEMPEST_SMTP_PORT"] |> smtp_port(),
      username: env["TEMPEST_SMTP_USERNAME"],
      password: env["TEMPEST_SMTP_PASSWORD"],
      ssl: env["TEMPEST_SMTP_SSL"] in ["1", "true", "TRUE"],
      tls: smtp_atom(env["TEMPEST_SMTP_TLS"], :if_available),
      auth: smtp_atom(env["TEMPEST_SMTP_AUTH"], :if_available)
    ]
  end

  defp build_mailer_config(:resend, env, boot_env, from_address) do
    require_from_address!(boot_env, from_address, :resend)

    [
      adapter: Swoosh.Adapters.Resend,
      api_key: require_env!(env, "TEMPEST_RESEND_API_KEY", boot_env)
    ]
  end

  defp require_from_address!(:prod, nil, provider) do
    raise """
    production email provider #{provider} selected without a from address.
    Set TEMPEST_EMAIL_FROM_ADDRESS (or the legacy TEMPEST_SMTP_FROM_ADDRESS alias) to a verified sender.
    """
  end

  defp require_from_address!(_boot_env, _from_address, _provider), do: :ok

  defp require_env!(env, key, :prod) do
    case env[key] do
      nil ->
        raise "production email provider requires #{key}; set it before starting the release."

      value ->
        value
    end
  end

  defp require_env!(env, key, _boot_env) do
    env[key]
  end

  defp smtp_port(nil), do: 587
  defp smtp_port(port_string) when is_binary(port_string), do: String.to_integer(port_string)

  defp smtp_atom(nil, default), do: default

  defp smtp_atom(value, _default) do
    String.to_existing_atom(value)
  end

  defp config_env do
    Application.get_env(:tempest, :env)
  end
end
