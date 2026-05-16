defmodule Tempest.Blobs.LocalStorage do
  @moduledoc """
  Local filesystem blob storage adapter.
  """

  alias Tempest.Config
  alias Tempest.RepoCore.{Cid, Did}

  @doc """
  Writes a temporary blob under the configured data directory.
  """
  @spec put_temp_blob(Config.t(), String.t(), String.t(), binary()) ::
          {:ok, %{cid: String.t(), path: String.t(), size: non_neg_integer()}} | {:error, term()}
  def put_temp_blob(%Config{} = config, did, cid, bytes)
      when is_binary(did) and is_binary(cid) and is_binary(bytes) do
    with {:ok, did} <- normalize_did(did),
         :ok <- validate_cid(cid),
         path <- temp_path(config, did, cid),
         :ok <- File.mkdir_p(Path.dirname(path)),
         :ok <- File.write(path, bytes) do
      {:ok, %{cid: cid, path: path, size: byte_size(bytes)}}
    end
  end

  @doc """
  Promotes a temporary blob into the permanent per-DID blob path.
  """
  @spec promote_blob(Config.t(), String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def promote_blob(%Config{} = config, did, cid) when is_binary(did) and is_binary(cid) do
    with {:ok, did} <- normalize_did(did),
         :ok <- validate_cid(cid),
         source <- temp_path(config, did, cid),
         destination <- blob_path(config, did, cid),
         :ok <- File.mkdir_p(Path.dirname(destination)) do
      cond do
        File.exists?(destination) ->
          _ = File.rm(source)
          {:ok, destination}

        File.exists?(source) ->
          case File.rename(source, destination) do
            :ok ->
              {:ok, destination}

            {:error, :exdev} ->
              copy_and_remove(source, destination)

            {:error, reason} ->
              {:error, reason}
          end

        true ->
          {:error, :blob_not_found}
      end
    end
  end

  @doc """
  Reads a promoted blob and returns bytes plus HTTP-serving metadata.
  """
  @spec get_blob(Config.t(), String.t(), String.t(), String.t()) ::
          {:ok, %{bytes: binary(), content_length: non_neg_integer(), mime_type: String.t()}} | {:error, term()}
  def get_blob(%Config{} = config, did, cid, mime_type \\ "application/octet-stream")
      when is_binary(did) and is_binary(cid) and is_binary(mime_type) do
    with {:ok, did} <- normalize_did(did),
         :ok <- validate_cid(cid),
         path <- blob_path(config, did, cid) do
      case File.read(path) do
        {:ok, bytes} ->
          {:ok, %{bytes: bytes, content_length: byte_size(bytes), mime_type: mime_type}}

        {:error, :enoent} ->
          {:error, :blob_not_found}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Deletes temp and promoted copies of a blob.
  """
  @spec delete_blob(Config.t(), String.t(), String.t()) :: :ok | {:error, term()}
  def delete_blob(%Config{} = config, did, cid) when is_binary(did) and is_binary(cid) do
    with {:ok, did} <- normalize_did(did),
         :ok <- validate_cid(cid),
         :ok <- remove_if_exists(temp_path(config, did, cid)) do
      remove_if_exists(blob_path(config, did, cid))
    end
  end

  @doc """
  Deletes only the temporary copy of a blob.
  """
  @spec delete_temp_blob(Config.t(), String.t(), String.t()) :: :ok | {:error, term()}
  def delete_temp_blob(%Config{} = config, did, cid) when is_binary(did) and is_binary(cid) do
    with {:ok, did} <- normalize_did(did),
         :ok <- validate_cid(cid) do
      remove_if_exists(temp_path(config, did, cid))
    end
  end

  @doc """
  Lists promoted blob CIDs for a DID.
  """
  @spec list_blobs(Config.t(), String.t(), keyword()) ::
          {:ok, %{required(:cids) => [String.t()], optional(:cursor) => String.t()}} | {:error, term()}
  def list_blobs(%Config{} = config, did, opts \\ []) when is_binary(did) and is_list(opts) do
    limit = Keyword.get(opts, :limit, 500)
    cursor = Keyword.get(opts, :cursor)

    with {:ok, did} <- normalize_did(did),
         :ok <- validate_limit(limit),
         :ok <- validate_cursor(cursor),
         directory <- Path.dirname(blob_path(config, did, "placeholder")),
         {:ok, cids} <- permanent_cids(directory) do
      page_after_cursor(cids, limit, cursor)
    end
  end

  defp copy_and_remove(source, destination) do
    with {:ok, _bytes} <- File.copy(source, destination),
         :ok <- File.rm(source) do
      {:ok, destination}
    end
  end

  defp permanent_cids(directory) do
    if File.dir?(directory) do
      cids =
        directory
        |> File.ls!()
        |> Enum.filter(&Cid.valid?/1)
        |> Enum.sort()

      {:ok, cids}
    else
      {:ok, []}
    end
  rescue
    e in File.Error -> {:error, e.reason}
  end

  defp page_after_cursor(cids, limit, cursor) do
    page_values =
      cids
      |> Enum.drop_while(fn cid -> cursor && cid <= cursor end)
      |> Enum.take(limit + 1)

    visible = Enum.take(page_values, limit)
    response = %{cids: visible}

    if length(page_values) > limit do
      {:ok, Map.put(response, :cursor, List.last(visible))}
    else
      {:ok, response}
    end
  end

  defp remove_if_exists(path) do
    case File.rm(path) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_did(did) do
    case Did.parse(did) do
      {:ok, did} -> {:ok, did}
      {:error, _reason} -> {:error, :invalid_did}
    end
  end

  defp validate_cid(cid) do
    if Cid.valid?(cid), do: :ok, else: {:error, :invalid_cid}
  end

  defp validate_limit(limit) when is_integer(limit) and limit in 1..1_000, do: :ok
  defp validate_limit(_limit), do: {:error, :invalid_limit}

  defp validate_cursor(nil), do: :ok
  defp validate_cursor(cursor) when is_binary(cursor), do: validate_cid(cursor)
  defp validate_cursor(_cursor), do: {:error, :invalid_cursor}

  defp blob_path(%Config{} = config, did, cid), do: Path.join([config.data_dir, "blobs", normalized_path_did(did), cid])

  defp temp_path(%Config{} = config, did, cid),
    do: Path.join([config.data_dir, "tmp", "blobs", normalized_path_did(did), cid])

  defp normalized_path_did(did) do
    String.replace(did, ~r/[^A-Za-z0-9._-]/, "_")
  end
end
