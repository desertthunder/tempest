defmodule Tempest.Blobs.S3Storage do
  @moduledoc """
  S3-compatible object storage adapter.

  This adapter assumes the configured endpoint accepts the supplied request
  options, including any authentication headers or Req options needed by the
  deployment. Metadata stays in `account.sqlite`.
  """

  @behaviour Tempest.Blobs.StorageAdapter

  alias Tempest.RepoCore.{Cid, Did}

  @impl true
  def put_temp_blob(config, did, cid, bytes) when is_list(config) and is_binary(bytes) do
    with {:ok, did} <- normalize_did(did),
         :ok <- validate_cid(cid),
         {:ok, request} <- request_options(config, temp_key(did, cid), method: :put, body: bytes) do
      case Req.request(request) do
        {:ok, %{status: status}} when status in 200..299 ->
          key = temp_key(did, cid)

          case verify_temp_blob(config, key, bytes) do
            :ok -> {:ok, %{cid: cid, path: key, size: byte_size(bytes)}}
            {:error, reason} -> {:error, reason}
          end

        {:ok, %{status: status}} ->
          {:error, {:s3_status, status}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @impl true
  def promote_blob(config, did, cid) when is_list(config) do
    with {:ok, did} <- normalize_did(did),
         :ok <- validate_cid(cid),
         source <- temp_key(did, cid),
         destination <- blob_key(did, cid),
         {:ok, request} <-
           request_options(config, destination,
             method: :put,
             headers: [{"x-amz-copy-source", copy_source(config, source)}]
           ) do
      case Req.request(request) do
        {:ok, %{status: status}} when status in 200..299 ->
          _ = delete_temp_blob(config, did, cid)
          {:ok, destination}

        {:ok, %{status: 404}} ->
          promote_blob_via_read_write(config, did, cid, source, destination)

        {:ok, %{status: status}} ->
          case promote_blob_via_read_write(config, did, cid, source, destination) do
            {:ok, promoted} -> {:ok, promoted}
            {:error, :blob_not_found} -> {:error, {:s3_status, status}}
            {:error, reason} -> {:error, reason}
          end

        {:error, reason} ->
          case promote_blob_via_read_write(config, did, cid, source, destination) do
            {:ok, promoted} -> {:ok, promoted}
            {:error, :blob_not_found} -> {:error, reason}
            {:error, fallback_reason} -> {:error, fallback_reason}
          end
      end
    end
  end

  @impl true
  def get_blob(config, did, cid, mime_type \\ "application/octet-stream") when is_list(config) do
    with {:ok, did} <- normalize_did(did),
         :ok <- validate_cid(cid),
         {:ok, request} <- request_options(config, blob_key(did, cid), method: :get) do
      case Req.request(request) do
        {:ok, %{status: status, body: bytes}} when status in 200..299 and is_binary(bytes) ->
          {:ok, %{bytes: bytes, content_length: byte_size(bytes), mime_type: mime_type}}

        {:ok, %{status: 404}} ->
          {:error, :blob_not_found}

        {:ok, %{status: status}} ->
          {:error, {:s3_status, status}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @impl true
  def delete_blob(config, did, cid) when is_list(config) do
    with :ok <- delete_temp_blob(config, did, cid) do
      delete_key(config, did, cid, &blob_key/2)
    end
  end

  @impl true
  def delete_temp_blob(config, did, cid) when is_list(config) do
    delete_key(config, did, cid, &temp_key/2)
  end

  @impl true
  def list_blobs(_config, _did, _opts \\ []) do
    {:error, :metadata_authoritative}
  end

  defp delete_key(config, did, cid, key_fun) do
    with {:ok, did} <- normalize_did(did),
         :ok <- validate_cid(cid),
         {:ok, request} <- request_options(config, key_fun.(did, cid), method: :delete) do
      case Req.request(request) do
        {:ok, %{status: status}} when status in 200..299 or status == 404 -> :ok
        {:ok, %{status: status}} -> {:error, {:s3_status, status}}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp request_options(config, key, opts) do
    endpoint_url = required!(config, :endpoint_url)
    bucket = bucket!(config)

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

  defp promote_blob_via_read_write(config, did, cid, source, destination) do
    case read_key(config, source) do
      {:ok, bytes} ->
        with :ok <- write_key(config, destination, bytes),
             :ok <- delete_temp_blob(config, did, cid) do
          {:ok, destination}
        end

      {:error, :blob_not_found} ->
        promote_existing_blob(config, did, cid, destination)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp promote_existing_blob(config, did, cid, destination) do
    case read_key(config, destination) do
      {:ok, _bytes} ->
        _ = delete_temp_blob(config, did, cid)
        {:ok, destination}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp verify_temp_blob(config, key, expected_bytes) do
    case read_key(config, key) do
      {:ok, ^expected_bytes} -> :ok
      {:ok, _other_bytes} -> {:error, :blob_content_mismatch}
      {:error, reason} -> {:error, reason}
    end
  end

  defp read_key(config, key) do
    with {:ok, request} <- request_options(config, key, method: :get) do
      case Req.request(request) do
        {:ok, %{status: status, body: bytes}} when status in 200..299 and is_binary(bytes) -> {:ok, bytes}
        {:ok, %{status: 404}} -> {:error, :blob_not_found}
        {:ok, %{status: status}} -> {:error, {:s3_status, status}}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp write_key(config, key, bytes) when is_binary(bytes) do
    with {:ok, request} <- request_options(config, key, method: :put, body: bytes) do
      case Req.request(request) do
        {:ok, %{status: status}} when status in 200..299 -> :ok
        {:ok, %{status: status}} -> {:error, {:s3_status, status}}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp object_url(endpoint_url, bucket, key) do
    endpoint_url
    |> String.trim_trailing("/")
    |> Kernel.<>("/" <> URI.encode(bucket) <> "/" <> encode_key(key))
  end

  defp copy_source(config, key), do: "/" <> URI.encode(bucket!(config)) <> "/" <> encode_key(key)

  defp encode_key(key) do
    key
    |> String.split("/")
    |> Enum.map(fn segment -> URI.encode(segment, &URI.char_unreserved?/1) end)
    |> Enum.join("/")
  end

  defp default_headers(config), do: Keyword.get(config, :headers, [])

  defp required!(config, key), do: Keyword.fetch!(config, key)
  defp bucket!(config), do: required!(config, :bucket)

  defp temp_key(did, cid), do: "temp/blobs/" <> did <> "/" <> cid
  defp blob_key(did, cid), do: "blobs/" <> did <> "/" <> cid

  defp normalize_did(did) do
    case Did.parse(did) do
      {:ok, did} -> {:ok, did}
      {:error, _reason} -> {:error, :invalid_did}
    end
  end

  defp validate_cid(cid) do
    if Cid.valid?(cid), do: :ok, else: {:error, :invalid_cid}
  end
end
