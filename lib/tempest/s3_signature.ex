defmodule Tempest.S3Signature do
  @moduledoc """
  Minimal AWS Signature Version 4 signing for S3-compatible object requests.
  """

  def sign(request, config) when is_list(request) and is_list(config) do
    with access_key when is_binary(access_key) <- Keyword.get(config, :access_key_id),
         secret_key when is_binary(secret_key) <- Keyword.get(config, :secret_access_key) do
      url = Keyword.fetch!(request, :url)
      method = request |> Keyword.fetch!(:method) |> to_string() |> String.upcase()
      body = Keyword.get(request, :body, "")
      region = Keyword.get(config, :region, "auto")
      service = Keyword.get(config, :service, "s3")
      now = Keyword.get(config, :signing_time) || DateTime.utc_now()
      amz_date = amz_date(now)
      date = String.slice(amz_date, 0, 8)
      payload_hash = sha256_hex(body)
      uri = URI.parse(url)
      host = host_header(uri)

      signing_headers = [
        {"host", host},
        {"x-amz-content-sha256", payload_hash},
        {"x-amz-date", amz_date}
      ]

      existing_headers = request |> Keyword.get(:headers, []) |> List.wrap()
      headers = merge_headers(existing_headers, signing_headers)
      authorization = authorization(method, uri, headers, payload_hash, access_key, secret_key, date, region, service)

      Keyword.put(request, :headers, merge_headers(headers, [{"authorization", authorization}]))
    else
      _missing -> request
    end
  end

  defp authorization(method, uri, headers, payload_hash, access_key, secret_key, date, region, service) do
    {canonical_headers, signed_headers} = canonical_headers(headers)
    scope = Enum.join([date, region, service, "aws4_request"], "/")

    canonical_request =
      [
        method,
        uri.path || "/",
        uri.query || "",
        canonical_headers,
        signed_headers,
        payload_hash
      ]
      |> Enum.join("\n")

    string_to_sign =
      Enum.join(["AWS4-HMAC-SHA256", amz_date_from_headers(headers), scope, sha256_hex(canonical_request)], "\n")

    signature = signing_key(secret_key, date, region, service) |> hmac(string_to_sign) |> Base.encode16(case: :lower)

    "AWS4-HMAC-SHA256 Credential=#{access_key}/#{scope}, SignedHeaders=#{signed_headers}, Signature=#{signature}"
  end

  defp canonical_headers(headers) do
    normalized =
      headers
      |> Enum.map(fn {key, value} ->
        {key |> to_string() |> String.downcase(), value |> to_string() |> String.trim()}
      end)
      |> Enum.sort_by(fn {key, _value} -> key end)

    canonical = Enum.map_join(normalized, "", fn {key, value} -> key <> ":" <> value <> "\n" end)
    signed = normalized |> Enum.map(fn {key, _value} -> key end) |> Enum.join(";")
    {canonical, signed}
  end

  defp amz_date_from_headers(headers) do
    {_key, value} = Enum.find(headers, fn {key, _value} -> String.downcase(to_string(key)) == "x-amz-date" end)
    value
  end

  defp merge_headers(existing, additions) do
    addition_keys = additions |> Enum.map(fn {key, _value} -> String.downcase(to_string(key)) end) |> MapSet.new()
    kept = Enum.reject(existing, fn {key, _value} -> MapSet.member?(addition_keys, String.downcase(to_string(key))) end)
    kept ++ additions
  end

  defp signing_key(secret_key, date, region, service) do
    ("AWS4" <> secret_key)
    |> hmac(date)
    |> hmac(region)
    |> hmac(service)
    |> hmac("aws4_request")
  end

  defp hmac(key, data), do: :crypto.mac(:hmac, :sha256, key, data)
  defp sha256_hex(data), do: :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)

  defp amz_date(%DateTime{} = dt) do
    dt
    |> DateTime.truncate(:second)
    |> Calendar.strftime("%Y%m%dT%H%M%SZ")
  end

  defp host_header(%URI{host: host, port: nil}), do: host

  defp host_header(%URI{host: host, port: port, scheme: scheme}) when scheme in ["http", "https"] do
    default = if scheme == "https", do: 443, else: 80
    if port == default, do: host, else: host <> ":" <> Integer.to_string(port)
  end
end
