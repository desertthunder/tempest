defmodule Tempest.DpopProof do
  @moduledoc false

  def key, do: JOSE.JWK.generate_key({:ec, "P-256"})

  def default_key do
    case :persistent_term.get({__MODULE__, :default_key}, nil) do
      nil ->
        key = key()
        :persistent_term.put({__MODULE__, :default_key}, key)
        key

      key ->
        key
    end
  end

  def public_jwk(jwk) do
    jwk
    |> JOSE.JWK.to_public()
    |> JOSE.JWK.to_map()
    |> elem(1)
  end

  def proof(method, url, nonce, opts \\ []) do
    jwk = Keyword.get_lazy(opts, :key, &default_key/0)
    alg = Keyword.get(opts, :alg, "ES256")
    header_jwk = Keyword.get_lazy(opts, :jwk, fn -> public_jwk(jwk) end)

    headers = %{
      "typ" => Keyword.get(opts, :typ, "dpop+jwt"),
      "alg" => alg,
      "jwk" => header_jwk
    }

    payload = %{
      "htu" => Keyword.get(opts, :htu, url),
      "htm" => Keyword.get(opts, :htm, method),
      "iat" => Keyword.get_lazy(opts, :iat, fn -> DateTime.utc_now() |> DateTime.to_unix() end),
      "jti" => Keyword.get_lazy(opts, :jti, fn -> Ecto.UUID.generate() end),
      "nonce" => Keyword.get(opts, :nonce, nonce)
    }

    {_modules, compact} = JOSE.JWT.sign(jwk, headers, payload) |> JOSE.JWS.compact()
    compact
  end
end
