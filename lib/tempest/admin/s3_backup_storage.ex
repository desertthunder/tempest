defmodule Tempest.Admin.S3BackupStorage do
  @moduledoc """
  S3-compatible backup archive upload helper.
  """

  def upload_file(config, key, path) when is_list(config) and is_binary(key) and is_binary(path) do
    with {:ok, bytes} <- File.read(path),
         {:ok, request} <- request_options(config, key, method: :put, body: bytes) do
      case Req.request(request) do
        {:ok, %{status: status}} when status in 200..299 ->
          {:ok, %{key: key, bytes: byte_size(bytes)}}

        {:ok, %{status: status}} ->
          {:error, {:s3_status, status}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp request_options(config, key, opts) do
    endpoint_url = Keyword.fetch!(config, :endpoint_url)
    bucket = Keyword.fetch!(config, :bucket)

    request =
      config
      |> Keyword.get(:req_options, [])
      |> Keyword.merge(opts)
      |> Keyword.update(:headers, default_headers(config), &(default_headers(config) ++ List.wrap(&1)))
      |> Keyword.put(:url, object_url(endpoint_url, bucket, key))
      |> Tempest.S3Signature.sign(config)

    {:ok, request}
  rescue
    e in KeyError -> {:error, {:missing_s3_config, e.key}}
  end

  defp object_url(endpoint_url, bucket, key) do
    endpoint_url
    |> String.trim_trailing("/")
    |> Kernel.<>("/" <> URI.encode(bucket) <> "/" <> encode_key(key))
  end

  defp encode_key(key) do
    key
    |> String.split("/")
    |> Enum.map(fn segment -> URI.encode(segment, &URI.char_unreserved?/1) end)
    |> Enum.join("/")
  end

  defp default_headers(config), do: Keyword.get(config, :headers, [])
end
