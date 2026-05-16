defmodule Tempest.Config do
  @moduledoc """
  Runtime configuration boundary for Tempest-specific settings.
  """

  @enforce_keys [:hostname, :public_url, :data_dir, :blob_max_bytes]
  defstruct [:hostname, :public_url, :data_dir, :blob_max_bytes]

  @type t :: %__MODULE__{
          hostname: String.t(),
          public_url: String.t(),
          data_dir: String.t(),
          blob_max_bytes: pos_integer()
        }

  @default_secret_key_bases [
    "+uUQkQUThGq4zX4Vl0a0Jfn8JGPw6ZlqzIJ2FRI+qzdG6VLTMlZN0Pyq7xKGQBRH",
    "jUcVlVDRHeNy2EGaVJyMzeDJ1AcW9fVjUDsiCRVq/sHuh0JxjgVHT+0FVrs49BPO"
  ]

  @doc """
  Loads and validates Tempest runtime configuration from application env.
  """
  def load! do
    :tempest
    |> Application.get_env(__MODULE__, [])
    |> validate!(
      env: Application.get_env(:tempest, :env, :prod),
      endpoint_config: Application.get_env(:tempest, TempestWeb.Endpoint, [])
    )
  end

  def account_db_path(%__MODULE__{data_dir: data_dir}), do: Path.join(data_dir, "account.sqlite")

  def sequencer_db_path(%__MODULE__{data_dir: data_dir}),
    do: Path.join(data_dir, "sequencer.sqlite")

  def repo_db_path(%__MODULE__{data_dir: data_dir}, did) when is_binary(did) do
    Path.join([data_dir, "repos", repo_db_filename(did)])
  end

  def data_dirs(%__MODULE__{data_dir: data_dir}) do
    Enum.map(~w(repos blobs tmp backups), &Path.join(data_dir, &1))
  end

  @doc """
  Validates Tempest configuration and returns a normalized struct.
  """
  def validate!(config, opts \\ []) when is_list(config) do
    config =
      %__MODULE__{
        hostname: Keyword.get(config, :hostname),
        public_url: Keyword.get(config, :public_url),
        data_dir: Keyword.get(config, :data_dir),
        blob_max_bytes: Keyword.get(config, :blob_max_bytes)
      }

    env = Keyword.get(opts, :env, Application.get_env(:tempest, :env, :prod))
    endpoint_config = Keyword.get(opts, :endpoint_config, [])

    with :ok <- validate_hostname(config.hostname),
         :ok <- validate_public_url(config.public_url, config.hostname),
         :ok <- validate_data_dir(config.data_dir),
         :ok <- validate_blob_max_bytes(config.blob_max_bytes),
         :ok <- validate_prod_secret(env, endpoint_config) do
      config
    else
      {:error, reason} -> raise RuntimeError, "invalid Tempest config: #{reason}"
    end
  end

  defp validate_hostname(hostname) when is_binary(hostname) do
    hostname = String.trim(hostname)

    cond do
      hostname == "" ->
        {:error, "hostname is required"}

      String.contains?(hostname, ["://", "/", "\\", " "]) ->
        {:error, "hostname must be a bare host without scheme, port, path, or spaces"}

      hostname == "localhost" ->
        :ok

      ip_address?(hostname) ->
        :ok

      dns_hostname?(hostname) ->
        :ok

      true ->
        {:error, "hostname must be localhost, an IP address, or a DNS hostname"}
    end
  end

  defp validate_hostname(_hostname), do: {:error, "hostname is required"}

  defp validate_public_url(public_url, hostname) when is_binary(public_url) do
    uri = URI.parse(public_url)

    cond do
      uri.scheme not in ["http", "https"] ->
        {:error, "public_url must use http or https"}

      is_nil(uri.host) or uri.host == "" ->
        {:error, "public_url must include a host"}

      uri.host != hostname ->
        {:error, "public_url host must match hostname"}

      not is_nil(uri.query) or not is_nil(uri.fragment) ->
        {:error, "public_url must not include query string or fragment"}

      true ->
        :ok
    end
  end

  defp validate_public_url(_public_url, _hostname), do: {:error, "public_url is required"}

  defp validate_data_dir(data_dir) when is_binary(data_dir) do
    cond do
      String.trim(data_dir) == "" ->
        {:error, "data_dir is required"}

      Path.type(data_dir) != :absolute ->
        {:error, "data_dir must be an absolute path"}

      true ->
        :ok
    end
  end

  defp validate_data_dir(_data_dir), do: {:error, "data_dir is required"}

  defp validate_blob_max_bytes(blob_max_bytes)
       when is_integer(blob_max_bytes) and blob_max_bytes > 0,
       do: :ok

  defp validate_blob_max_bytes(_blob_max_bytes),
    do: {:error, "blob_max_bytes must be a positive integer"}

  defp validate_prod_secret(:prod, endpoint_config) do
    secret_key_base = Keyword.get(endpoint_config, :secret_key_base)

    cond do
      not is_binary(secret_key_base) or secret_key_base == "" ->
        {:error, "production secret_key_base is required"}

      secret_key_base in @default_secret_key_bases ->
        {:error, "production secret_key_base cannot use a default development or test secret"}

      true ->
        :ok
    end
  end

  defp validate_prod_secret(_env, _endpoint_config), do: :ok

  defp ip_address?(hostname) do
    case :inet.parse_address(String.to_charlist(hostname)) do
      {:ok, _address} -> true
      {:error, _reason} -> false
    end
  end

  defp dns_hostname?(hostname) do
    byte_size(hostname) <= 253 and
      hostname
      |> String.split(".")
      |> Enum.all?(&dns_label?/1)
  end

  defp dns_label?(label) do
    String.match?(label, ~r/\A[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\z/)
  end

  defp repo_db_filename(did) do
    did
    |> String.replace(~r/[^A-Za-z0-9._-]/, "_")
    |> Kernel.<>(".sqlite")
  end
end
