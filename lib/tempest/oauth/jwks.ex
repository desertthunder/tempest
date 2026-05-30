defmodule Tempest.OAuth.Jwks do
  @moduledoc """
  File-backed OAuth signing key registry and rotation boundary.

  Current implementation publishes ES256 public keys for `/oauth/jwks`. The file
  stores public/private material under Tempest's data directory so keys survive
  restarts. Rotation creates a new active key and keeps old keys published until
  existing tokens have aged out.

  `kid` means "key ID". It is the opaque identifier copied into a JWT header so
  verifiers can pick the matching public key from the JWKS. It is not secret,
  not derived from key material, and must remain unique for each generated key.

  Rotation plan:

    * rotate on operator command or incident by calling `rotate_key/0`;
    * sign new tokens with `active_key/0` (implemented by token work later);
    * keep retired public keys in JWKS for at least the maximum access-token and
      refresh-token grace window;
    * prune retired private material only after no valid token can reference the
      key id;
    * never reuse `kid` values.
  """

  alias Tempest.Config

  @curve :prime256v1
  @jwk_crv "P-256"
  @alg "ES256"
  @kty "EC"

  @doc """
  Returns public JWKS, creating an initial active key if needed.
  """
  def public_jwks do
    {:ok, state} = ensure_state()

    keys =
      state["keys"]
      |> Enum.map(&Map.take(&1, ["kty", "kid", "use", "alg", "crv", "x", "y"]))

    %{"keys" => keys}
  end

  @doc """
  Returns the active private key record for future token signing code.
  """
  def active_key do
    {:ok, state} = ensure_state()
    active_kid = state["active_kid"]

    case Enum.find(state["keys"], &(&1["kid"] == active_kid)) do
      nil -> {:error, :active_key_missing}
      key -> {:ok, key}
    end
  end

  @doc """
  Rotates to a new active ES256 key while keeping prior keys published.
  """
  def rotate_key do
    {:ok, state} = ensure_state()
    key = generate_key()

    new_state = %{
      "active_kid" => key["kid"],
      "keys" => [key | state["keys"]],
      "rotated_at" => DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
    }

    with :ok <- persist_state(new_state) do
      {:ok, key}
    end
  end

  @doc """
  Path to the JWKS registry file.
  """
  def path do
    :tempest
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get_lazy(:path, fn ->
      Tempest.Config.load!()
      |> Config.data_dirs()
      |> Enum.find(&String.ends_with?(&1, "/tmp"))
      |> Path.dirname()
      |> Path.join("oauth_jwks.json")
    end)
  end

  defp ensure_state do
    case File.read(path()) do
      {:ok, body} ->
        Jason.decode(body)

      {:error, :enoent} ->
        state = initial_state()

        with :ok <- persist_state(state) do
          {:ok, state}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp initial_state do
    key = generate_key()

    %{
      "active_kid" => key["kid"],
      "keys" => [key],
      "rotated_at" => DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
    }
  end

  defp persist_state(state) do
    file = path()
    dir = Path.dirname(file)
    tmp = file <> ".tmp"

    with :ok <- File.mkdir_p(dir),
         :ok <- File.write(tmp, Jason.encode!(state, pretty: true)),
         :ok <- File.rename(tmp, file) do
      :ok
    end
  end

  defp generate_key do
    {public_key, private_key} = :crypto.generate_key(:ecdh, @curve)
    <<4, x::binary-size(32), y::binary-size(32)>> = public_key

    %{
      "kty" => @kty,
      "kid" => random_key_id(),
      "use" => "sig",
      "alg" => @alg,
      "crv" => @jwk_crv,
      "x" => base64url(x),
      "y" => base64url(y),
      "d" => base64url(private_key),
      "created_at" => DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
    }
  end

  defp random_key_id do
    16
    |> :crypto.strong_rand_bytes()
    |> base64url()
  end

  defp base64url(binary), do: Base.url_encode64(binary, padding: false)
end
