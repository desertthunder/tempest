defmodule Tempest.Blobs do
  @moduledoc """
  Blob validation and CID helpers.

  This module is intentionally independent from HTTP handling. Upload routes can
  pass already-read bytes, the declared content length, and the declared MIME
  type through this boundary before inserting metadata or writing storage.
  """

  alias Tempest.Config
  alias Tempest.Repo
  alias Tempest.RepoCore.Cid
  alias Tempest.Storage.Timestamp

  @type validation_error ::
          :blob_too_large
          | :invalid_content_length
          | :content_length_mismatch
          | :missing_mime_type
          | :invalid_mime_type
          | :mime_type_mismatch

  @temp_ttl_seconds 60 * 60 * 6

  @doc """
  Returns the canonical raw CID string for blob bytes.
  """
  @spec cid_for(binary()) :: String.t()
  def cid_for(bytes) when is_binary(bytes) do
    bytes
    |> Cid.for_raw()
    |> Cid.to_string()
  end

  @doc """
  Validates upload bytes against size and MIME boundaries.
  """
  @spec validate_upload(binary(), term(), term(), Config.t()) ::
          {:ok, %{cid: String.t(), size: non_neg_integer(), mime_type: String.t(), sniffed_mime_type: String.t()}}
          | {:error, validation_error()}
  def validate_upload(bytes, declared_size, declared_mime_type, %Config{} = config) when is_binary(bytes) do
    actual_size = byte_size(bytes)

    with {:ok, declared_size} <- normalize_content_length(declared_size),
         :ok <- validate_actual_size(actual_size, declared_size, config.blob_max_bytes),
         {:ok, mime_type} <- validate_mime_type(bytes, declared_mime_type) do
      {:ok,
       %{
         cid: cid_for(bytes),
         size: actual_size,
         mime_type: mime_type.declared,
         sniffed_mime_type: mime_type.sniffed
       }}
    end
  end

  def validate_upload(_bytes, _declared_size, _declared_mime_type, %Config{}), do: {:error, :invalid_content_length}

  @doc """
  Inserts or refreshes temporary blob metadata.
  """
  @spec put_temp_metadata(String.t(), map()) :: :ok | {:error, term()}
  def put_temp_metadata(did, %{cid: cid, mime_type: mime_type, size: size})
      when is_binary(did) and is_binary(cid) and is_binary(mime_type) and is_integer(size) and size >= 0 do
    now = Timestamp.iso8601_utc()
    temp_expires_at = DateTime.utc_now() |> DateTime.add(@temp_ttl_seconds, :second) |> DateTime.to_iso8601()

    sql = """
    INSERT INTO blob_metadata (did, cid, mime_type, size, state, inserted_at, updated_at, temp_expires_at, referenced_at)
    VALUES (?1, ?2, ?3, ?4, 'temp', ?5, ?5, ?6, NULL)
    ON CONFLICT(did, cid) DO UPDATE SET
      mime_type = excluded.mime_type,
      size = excluded.size,
      state = CASE WHEN blob_metadata.state = 'public' THEN 'public' ELSE 'temp' END,
      updated_at = excluded.updated_at,
      temp_expires_at = CASE WHEN blob_metadata.state = 'public' THEN NULL ELSE excluded.temp_expires_at END,
      referenced_at = CASE WHEN blob_metadata.state = 'public' THEN blob_metadata.referenced_at ELSE NULL END
    """

    case Repo.query(sql, [did, cid, mime_type, size, now, temp_expires_at]) do
      {:ok, _result} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns blob metadata for a DID/CID pair.
  """
  @spec get_metadata(String.t(), String.t()) :: {:ok, map()} | {:error, :blob_not_found | term()}
  def get_metadata(did, cid) when is_binary(did) and is_binary(cid) do
    sql = """
    SELECT did, cid, mime_type, size, state, inserted_at, updated_at, temp_expires_at, referenced_at
    FROM blob_metadata
    WHERE did = ?1 AND cid = ?2
    """

    case Repo.query(sql, [did, cid]) do
      {:ok, %{rows: [[did, cid, mime_type, size, state, inserted_at, updated_at, temp_expires_at, referenced_at]]}} ->
        {:ok,
         %{
           did: did,
           cid: cid,
           mime_type: mime_type,
           size: size,
           state: state,
           inserted_at: inserted_at,
           updated_at: updated_at,
           temp_expires_at: temp_expires_at,
           referenced_at: referenced_at
         }}

      {:ok, %{rows: []}} ->
        {:error, :blob_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Lists public blob CIDs from authoritative local metadata.
  """
  @spec list_public(String.t(), keyword()) ::
          {:ok, %{required(:cids) => [String.t()], optional(:cursor) => String.t()}} | {:error, term()}
  def list_public(did, opts \\ []) when is_binary(did) and is_list(opts) do
    limit = Keyword.fetch!(opts, :limit)
    cursor = Keyword.get(opts, :cursor)

    sql = """
    SELECT cid
    FROM blob_metadata
    WHERE did = ?1 AND state = 'public' AND (?2 IS NULL OR cid > ?2)
    ORDER BY cid ASC
    LIMIT ?3
    """

    case Repo.query(sql, [did, cursor, limit + 1]) do
      {:ok, %{rows: rows}} ->
        cids = Enum.map(rows, fn [cid] -> cid end)
        visible = Enum.take(cids, limit)
        response = %{cids: visible}

        if length(cids) > limit do
          {:ok, Map.put(response, :cursor, List.last(visible))}
        else
          {:ok, response}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Returns public and missing referenced blob counts for an account.
  """
  def status_counts(did, referenced_count \\ 0) when is_binary(did) and is_integer(referenced_count) do
    case Repo.query("SELECT COUNT(*) FROM blob_metadata WHERE did = ?1 AND state = 'public'", [did]) do
      {:ok, %{rows: [[public_count]]}} when is_integer(public_count) ->
        {:ok, %{blob_count: public_count, missing_blob_count: max(referenced_count - public_count, 0)}}

      {:ok, _result} ->
        {:error, :unexpected_count_result}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Fetches public metadata only. Temp uploads are deliberately invisible.
  """
  @spec get_public_metadata(String.t(), String.t()) :: {:ok, map()} | {:error, :blob_not_found | term()}
  def get_public_metadata(did, cid) when is_binary(did) and is_binary(cid) do
    with {:ok, metadata} <- get_metadata(did, cid) do
      if metadata.state == "public" do
        {:ok, metadata}
      else
        {:error, :blob_not_found}
      end
    end
  end

  @doc """
  Deletes expired temporary blob metadata rows and their local bytes.
  """
  @spec delete_expired_temp(Config.t(), DateTime.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  def delete_expired_temp(%Config{} = config, %DateTime{} = now) do
    cutoff = DateTime.to_iso8601(now)

    sql = """
    SELECT did, cid
    FROM blob_metadata
    WHERE state = 'temp' AND temp_expires_at IS NOT NULL AND temp_expires_at <= ?1
    ORDER BY did ASC, cid ASC
    """

    with {:ok, %{rows: rows}} <- Repo.query(sql, [cutoff]) do
      Enum.reduce_while(rows, {:ok, 0}, fn [did, cid], {:ok, count} ->
        with :ok <- Tempest.Blobs.LocalStorage.delete_temp_blob(config, did, cid),
             {:ok, _result} <-
               Repo.query("DELETE FROM blob_metadata WHERE did = ?1 AND cid = ?2 AND state = 'temp'", [did, cid]) do
          {:cont, {:ok, count + 1}}
        else
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
    end
  end

  @doc """
  Ensures all CIDs are present in local metadata for the DID.
  """
  @spec ensure_present(String.t(), [String.t()]) :: :ok | {:error, :missing_blob | term()}
  def ensure_present(_did, []), do: :ok

  def ensure_present(did, cids) when is_binary(did) and is_list(cids) do
    Enum.reduce_while(Enum.uniq(cids), :ok, fn cid, :ok ->
      case get_metadata(did, cid) do
        {:ok, _metadata} -> {:cont, :ok}
        {:error, :blob_not_found} -> {:halt, {:error, :missing_blob}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @doc """
  Marks referenced blobs public after their record commit succeeds.
  """
  @spec mark_public(String.t(), [String.t()]) :: :ok | {:error, term()}
  def mark_public(_did, []), do: :ok

  def mark_public(did, cids) when is_binary(did) and is_list(cids) do
    now = Timestamp.iso8601_utc()

    Enum.reduce_while(Enum.uniq(cids), :ok, fn cid, :ok ->
      sql = """
      UPDATE blob_metadata
      SET state = 'public', updated_at = ?3, referenced_at = ?3, temp_expires_at = NULL
      WHERE did = ?1 AND cid = ?2
      """

      case Repo.query(sql, [did, cid, now]) do
        {:ok, %{num_rows: 1}} -> {:cont, :ok}
        {:ok, _result} -> {:halt, {:error, :missing_blob}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @doc """
  Deletes metadata rows for blobs that are no longer referenced.
  """
  @spec delete_metadata(String.t(), [String.t()]) :: :ok | {:error, term()}
  def delete_metadata(_did, []), do: :ok

  def delete_metadata(did, cids) when is_binary(did) and is_list(cids) do
    Enum.reduce_while(Enum.uniq(cids), :ok, fn cid, :ok ->
      case Repo.query("DELETE FROM blob_metadata WHERE did = ?1 AND cid = ?2", [did, cid]) do
        {:ok, _result} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @doc """
  Extracts valid AT Protocol blob reference CIDs from a record-shaped value.
  """
  @spec referenced_cids(term()) :: [String.t()]
  def referenced_cids(value) do
    value
    |> collect_blob_cids([])
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  Returns a CDN URL for a public blob when CDN redirects are configured.
  """
  @spec cdn_url(String.t(), String.t()) :: {:ok, String.t()} | :disabled
  def cdn_url(did, cid) when is_binary(did) and is_binary(cid) do
    case Keyword.get(blob_config(), :cdn_base_url) do
      base_url when is_binary(base_url) and base_url != "" ->
        {:ok, base_url |> String.trim_trailing("/") |> Kernel.<>("/blobs/" <> encode_path_segment(did) <> "/" <> cid)}

      _disabled ->
        :disabled
    end
  end

  @doc """
  Validates the declared content length against the actual byte size and limit.
  """
  @spec validate_size(non_neg_integer(), term(), pos_integer()) ::
          :ok | {:error, :invalid_content_length | :content_length_mismatch | :blob_too_large}
  def validate_size(actual_size, declared_size, max_bytes) when is_integer(actual_size) and actual_size >= 0 do
    with {:ok, declared_size} <- normalize_content_length(declared_size) do
      validate_actual_size(actual_size, declared_size, max_bytes)
    end
  end

  @doc """
  Validates a declared MIME type and rejects known sniffed mismatches.
  """
  @spec validate_mime_type(binary(), term()) ::
          {:ok, %{declared: String.t(), sniffed: String.t()}}
          | {:error, :missing_mime_type | :invalid_mime_type | :mime_type_mismatch}
  def validate_mime_type(bytes, declared_mime_type) when is_binary(bytes) do
    with {:ok, declared} <- normalize_mime_type(declared_mime_type),
         sniffed <- sniff_mime_type(bytes),
         :ok <- ensure_mime_match(declared, sniffed) do
      {:ok, %{declared: declared, sniffed: sniffed}}
    end
  end

  @doc """
  Best-effort MIME sniffing for formats Tempest can identify without external dependencies.
  """
  @spec sniff_mime_type(binary()) :: String.t()
  def sniff_mime_type(<<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, _rest::binary>>), do: "image/png"
  def sniff_mime_type(<<0xFF, 0xD8, 0xFF, _rest::binary>>), do: "image/jpeg"
  def sniff_mime_type(<<"GIF87a", _rest::binary>>), do: "image/gif"
  def sniff_mime_type(<<"GIF89a", _rest::binary>>), do: "image/gif"
  def sniff_mime_type(<<"%PDF-", _rest::binary>>), do: "application/pdf"
  def sniff_mime_type(<<"RIFF", _size::binary-size(4), "WEBP", _rest::binary>>), do: "image/webp"

  def sniff_mime_type(bytes) when is_binary(bytes) do
    if textual?(bytes), do: "text/plain", else: "application/octet-stream"
  end

  defp normalize_content_length(length) when is_integer(length) and length >= 0, do: {:ok, length}

  defp normalize_content_length(length) when is_binary(length) do
    case Integer.parse(String.trim(length)) do
      {length, ""} when length >= 0 -> {:ok, length}
      _invalid -> {:error, :invalid_content_length}
    end
  end

  defp normalize_content_length(_length), do: {:error, :invalid_content_length}

  defp validate_actual_size(actual_size, declared_size, max_bytes) when is_integer(max_bytes) and max_bytes > 0 do
    cond do
      actual_size != declared_size -> {:error, :content_length_mismatch}
      actual_size > max_bytes -> {:error, :blob_too_large}
      true -> :ok
    end
  end

  defp normalize_mime_type(nil), do: {:error, :missing_mime_type}

  defp normalize_mime_type(mime_type) when is_binary(mime_type) do
    mime_type =
      mime_type
      |> String.split(";", parts: 2)
      |> List.first()
      |> String.trim()
      |> String.downcase()

    if String.match?(mime_type, ~r/\A[a-z0-9][a-z0-9!#$&^_.+-]*\/[a-z0-9][a-z0-9!#$&^_.+-]*\z/) do
      {:ok, mime_type}
    else
      {:error, :invalid_mime_type}
    end
  end

  defp normalize_mime_type(_mime_type), do: {:error, :invalid_mime_type}

  defp ensure_mime_match(_declared, "application/octet-stream"), do: :ok
  defp ensure_mime_match("application/octet-stream", _sniffed), do: :ok
  defp ensure_mime_match("application/json", "text/plain"), do: :ok
  defp ensure_mime_match("application/ld+json", "text/plain"), do: :ok
  defp ensure_mime_match("application/cbor", "application/octet-stream"), do: :ok
  defp ensure_mime_match(declared, declared), do: :ok
  defp ensure_mime_match("text/" <> _subtype, "text/plain"), do: :ok
  defp ensure_mime_match(_declared, _sniffed), do: {:error, :mime_type_mismatch}

  defp textual?(<<>>), do: true

  defp textual?(bytes) do
    String.valid?(bytes) and not String.contains?(bytes, <<0>>) and printable_text?(bytes)
  end

  defp printable_text?(bytes) do
    bytes
    |> :binary.bin_to_list()
    |> Enum.all?(fn byte -> byte in [9, 10, 13] or byte in 32..126 or byte >= 128 end)
  end

  defp collect_blob_cids(%{"$type" => "blob", "ref" => %{"$link" => cid}}, acc) when is_binary(cid) do
    if Cid.valid?(cid), do: [cid | acc], else: acc
  end

  defp collect_blob_cids(%{"cid" => cid, "mimeType" => _mime_type} = value, acc) when is_binary(cid) do
    if Map.has_key?(value, "$type") and Cid.valid?(cid), do: [cid | acc], else: collect_map_blob_cids(value, acc)
  end

  defp collect_blob_cids(map, acc) when is_map(map), do: collect_map_blob_cids(map, acc)

  defp collect_blob_cids(list, acc) when is_list(list) do
    Enum.reduce(list, acc, &collect_blob_cids/2)
  end

  defp collect_blob_cids(_value, acc), do: acc

  defp collect_map_blob_cids(map, acc) do
    map
    |> Map.values()
    |> Enum.reduce(acc, &collect_blob_cids/2)
  end

  defp blob_config do
    Application.get_env(:tempest, __MODULE__, [])
  end

  defp encode_path_segment(value), do: URI.encode(value, &URI.char_unreserved?/1)
end
