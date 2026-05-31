defmodule Tempest.Security.Totp do
  @moduledoc """
  Minimal RFC 6238 TOTP helper used for account MFA and dev tooling.
  """

  @period 30
  @digits 6

  def new_secret(bytes \\ 20) do
    bytes |> :crypto.strong_rand_bytes() |> Base.encode32(case: :upper, padding: false)
  end

  def otpauth_uri(secret, issuer, label) do
    query = URI.encode_query(%{secret: secret, issuer: issuer, algorithm: "SHA1", digits: @digits, period: @period})
    "otpauth://totp/#{URI.encode(issuer)}:#{URI.encode(label)}?#{query}"
  end

  def code(secret, unix_time \\ System.system_time(:second)) do
    counter = div(unix_time, @period)

    secret
    |> decode_secret!()
    |> hotp(counter)
  end

  def valid?(secret, candidate, unix_time \\ System.system_time(:second), window \\ 1) do
    candidate = to_string(candidate) |> String.trim()

    Enum.any?(-window..window, fn offset ->
      expected = code(secret, unix_time + offset * @period)
      Plug.Crypto.secure_compare(expected, candidate)
    end)
  rescue
    _error -> false
  end

  defp hotp(key, counter) do
    hash = :crypto.mac(:hmac, :sha, key, <<counter::64>>)
    offset = hash |> :binary.at(19) |> Bitwise.band(0x0F)
    part = :binary.part(hash, offset, 4)
    <<value::32>> = part

    value
    |> Bitwise.band(0x7FFF_FFFF)
    |> rem(trunc(:math.pow(10, @digits)))
    |> Integer.to_string()
    |> String.pad_leading(@digits, "0")
  end

  defp decode_secret!(secret) do
    padding = rem(String.length(secret), 8)
    padded = if padding == 0, do: secret, else: secret <> String.duplicate("=", 8 - padding)
    Base.decode32!(padded, case: :mixed)
  end
end
