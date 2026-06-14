defmodule Tempest.Xrpc.Repo do
  @moduledoc """
  Handlers for `com.atproto.repo.*` XRPC methods.
  """

  alias Plug.Conn
  alias Tempest.Blobs
  alias Tempest.Config
  alias Tempest.Records

  @import_repo_max_bytes 100 * 1_024 * 1_024

  def import_repo(conn, _params, _method) do
    with {:ok, bytes, _conn} <- read_upload_body(conn, @import_repo_max_bytes) do
      case Records.import_repo(conn.assigns.auth_context, bytes) do
        {:ok, response} -> {:ok, response}
        {:error, reason} -> repo_error(reason)
      end
    else
      {:error, reason} -> repo_error(reason)
    end
  end

  def upload_blob(conn, _params, _method) do
    config = Config.load!()

    with {:ok, declared_size} <- content_length(conn),
         {:ok, declared_mime_type} <- content_type(conn),
         {:ok, bytes, conn} <- read_upload_body(conn, config.blob_max_bytes),
         {:ok, metadata} <- Blobs.validate_upload(bytes, declared_size, declared_mime_type, config),
         {:ok, _stored} <- Blobs.put_temp_blob(config, conn.assigns.auth_context.account.did, metadata.cid, bytes),
         :ok <- Blobs.put_temp_metadata(conn.assigns.auth_context.account.did, metadata) do
      Tempest.Telemetry.execute([:blob, :upload], %{count: 1, bytes: metadata.size}, %{
        did: conn.assigns.auth_context.account.did,
        mime_type: metadata.mime_type
      })

      {:ok,
       %{
         blob: %{
           "$type" => "blob",
           ref: %{"$link" => metadata.cid},
           mimeType: metadata.mime_type,
           size: metadata.size
         }
       }}
    else
      {:error, reason} -> repo_error(reason)
    end
  end

  def create_record(conn, params, _method) do
    case Records.create_record(conn.assigns.auth_context, params) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> repo_error(reason)
    end
  end

  def put_record(conn, params, _method) do
    case Records.put_record(conn.assigns.auth_context, params) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> repo_error(reason)
    end
  end

  def delete_record(conn, params, _method) do
    case Records.delete_record(conn.assigns.auth_context, params) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> repo_error(reason)
    end
  end

  def apply_writes(conn, params, _method) do
    case Records.apply_writes(conn.assigns.auth_context, params) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> repo_error(reason)
    end
  end

  def get_record(_conn, params, _method) do
    case Records.get_record(params) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> repo_error(reason)
    end
  end

  def list_records(_conn, params, _method) do
    case Records.list_records(params) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> repo_error(reason)
    end
  end

  def list_missing_blobs(conn, params, _method) do
    case Records.list_missing_blobs(conn.assigns.auth_context, params) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> repo_error(reason)
    end
  end

  def describe_repo(_conn, params, _method) do
    case Records.describe_repo(params) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> repo_error(reason)
    end
  end

  defp read_upload_body(conn, max_bytes) do
    case Conn.read_body(conn, length: max_bytes + 1, read_length: max_bytes + 1) do
      {:ok, bytes, conn} ->
        {:ok, bytes, conn}

      {:more, _partial, _conn} ->
        {:error, :blob_too_large}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp content_length(conn) do
    case Conn.get_req_header(conn, "content-length") do
      [value] -> {:ok, value}
      _headers -> {:error, :invalid_content_length}
    end
  end

  defp content_type(conn) do
    case Conn.get_req_header(conn, "content-type") do
      [value | _rest] -> {:ok, value}
      [] -> {:error, :missing_mime_type}
    end
  end

  defp repo_error(:duplicate_record), do: {:error, 409, "InvalidRequest", "record already exists"}

  defp repo_error(:invalid_swap),
    do: {:error, 409, "InvalidSwap", "swap condition does not match current repository state"}

  defp repo_error(:repo_mismatch), do: {:error, 400, "InvalidRequest", "repo must match the authenticated account"}
  defp repo_error(:repo_not_found), do: {:error, 400, "RepoNotFound", "repository could not be resolved"}
  defp repo_error(:record_not_found), do: {:error, 400, "RecordNotFound", "record could not be found"}
  defp repo_error(:invalid_repo), do: {:error, 400, "InvalidRequest", "repo is invalid"}
  defp repo_error(:invalid_collection), do: {:error, 400, "InvalidRequest", "collection is invalid"}
  defp repo_error(:invalid_rkey), do: {:error, 400, "InvalidRequest", "rkey is invalid"}
  defp repo_error(:invalid_cid), do: {:error, 400, "InvalidRequest", "cid is invalid"}
  defp repo_error(:invalid_limit), do: {:error, 400, "InvalidRequest", "limit is invalid"}
  defp repo_error(:invalid_cursor), do: {:error, 400, "InvalidRequest", "cursor is invalid"}
  defp repo_error(:invalid_reverse), do: {:error, 400, "InvalidRequest", "reverse must be a boolean"}
  defp repo_error(:invalid_swap_record), do: {:error, 400, "InvalidRequest", "swapRecord is invalid"}
  defp repo_error(:invalid_swap_commit), do: {:error, 400, "InvalidRequest", "swapCommit is invalid"}
  defp repo_error(:invalid_validate), do: {:error, 400, "InvalidRequest", "validate must be a boolean"}
  defp repo_error(:invalid_writes), do: {:error, 400, "InvalidRequest", "writes must contain 1 to 200 operations"}
  defp repo_error(:did_mismatch), do: {:error, 400, "InvalidRequest", "import CAR DID does not match account"}
  defp repo_error(:missing_commit_root), do: {:error, 400, "InvalidRequest", "import CAR is missing a commit root"}
  defp repo_error(:commit_block_missing), do: {:error, 400, "InvalidRequest", "import CAR is missing the commit block"}

  defp repo_error(:commit_cid_mismatch),
    do: {:error, 400, "InvalidRequest", "import commit CID does not match its bytes"}

  defp repo_error(:invalid_commit_signature), do: {:error, 400, "InvalidRequest", "import commit signature is invalid"}

  defp repo_error(:invalid_import_path),
    do: {:error, 400, "InvalidRequest", "import CAR contains an invalid record path"}

  defp repo_error(:invalid_write), do: {:error, 400, "InvalidRequest", "write operation is invalid"}

  defp repo_error(:duplicate_write),
    do: {:error, 400, "InvalidRequest", "create writes must not target the same collection and rkey more than once"}

  defp repo_error(:invalid_request_body), do: {:error, 400, "InvalidRequest", "request body is invalid"}
  defp repo_error(:invalid_content_length), do: {:error, 400, "InvalidRequest", "Content-Length is invalid"}

  defp repo_error(:content_length_mismatch),
    do: {:error, 400, "InvalidRequest", "Content-Length does not match body size"}

  defp repo_error(:blob_too_large), do: {:error, 400, "BlobTooLarge", "blob exceeds the configured size limit"}
  defp repo_error(:missing_mime_type), do: {:error, 400, "InvalidRequest", "Content-Type is required"}
  defp repo_error(:invalid_mime_type), do: {:error, 400, "InvalidRequest", "Content-Type is invalid"}
  defp repo_error(:mime_type_mismatch), do: {:error, 400, "InvalidRequest", "Content-Type does not match blob bytes"}
  defp repo_error(:missing_blob), do: {:error, 400, "InvalidRequest", "record references a missing blob"}
  defp repo_error(:missing_record_type), do: {:error, 400, "InvalidRequest", "record must include a $type field"}
  defp repo_error(:record_type_mismatch), do: {:error, 400, "InvalidRequest", "record $type must match collection"}
  defp repo_error(:unknown_lexicon), do: {:error, 400, "InvalidRequest", "record lexicon is unknown"}
  defp repo_error(:invalid_record), do: {:error, 400, "InvalidRequest", "record is invalid"}
  defp repo_error(:invalid_string), do: {:error, 400, "InvalidRequest", "record contains an invalid string"}
  defp repo_error(:max_depth_exceeded), do: {:error, 400, "InvalidRequest", "record nesting is too deep"}
  defp repo_error(:missing_signing_key), do: {:error, 500, "InternalServerError", "account has no active signing key"}
  defp repo_error({:field_too_small, field}), do: {:error, 400, "InvalidRequest", "#{field} is too small"}
  defp repo_error({:field_too_large, field}), do: {:error, 400, "InvalidRequest", "#{field} is too large"}
  defp repo_error({:car_error, _reason}), do: {:error, 400, "InvalidRequest", "import CAR is invalid"}
  defp repo_error({:commit_error, _reason}), do: {:error, 400, "InvalidRequest", "import commit is invalid"}

  defp repo_error({:missing_block, _cid}),
    do: {:error, 400, "InvalidRequest", "import CAR is missing a referenced block"}

  defp repo_error({:invalid_import_record, _reason}),
    do: {:error, 400, "InvalidRequest", "import CAR contains an invalid record block"}

  defp repo_error({:invalid_record_key, key_type}),
    do: {:error, 400, "InvalidRequest", "record key does not match Lexicon key type #{key_type}"}

  defp repo_error({:unsupported_record_key_type, key_type}),
    do: {:error, 400, "InvalidRequest", "record Lexicon key type #{key_type} is unsupported"}

  defp repo_error({:missing_field, field}),
    do: {:error, 400, "InvalidRequest", "#{field} is required"}

  defp repo_error({:unknown_field, field}),
    do: {:error, 400, "InvalidRequest", "#{field} is not defined by the Lexicon schema"}

  defp repo_error({:invalid_field, field}),
    do: {:error, 400, "InvalidRequest", "#{field} is invalid"}

  defp repo_error({:field_too_long, field}),
    do: {:error, 400, "InvalidRequest", "#{field} is too long"}

  defp repo_error({:field_too_short, field}),
    do: {:error, 400, "InvalidRequest", "#{field} is too short"}

  defp repo_error({:invalid_schema, field}),
    do: {:error, 400, "InvalidRequest", "#{field} schema is invalid"}

  defp repo_error({:unsupported_schema_type, field, type}),
    do: {:error, 400, "InvalidRequest", "#{field} schema type #{type} is unsupported"}

  defp repo_error({:invalid_commit_event, _reason}),
    do: {:error, 500, "InternalServerError", "repository commit event is invalid"}

  defp repo_error({:invalid_record_json, _reason}),
    do: {:error, 500, "InternalServerError", "stored record JSON is invalid"}

  defp repo_error({:invalid_record_cid, _reason}),
    do: {:error, 500, "InternalServerError", "stored record CID is invalid"}

  defp repo_error({:invalid_mst_node, _reason}),
    do: {:error, 500, "InternalServerError", "repository tree is invalid"}

  defp repo_error({:invalid_commit, _reason}),
    do: {:error, 500, "InternalServerError", "repository commit is invalid"}

  defp repo_error({:invalid_commit_cid, _reason}),
    do: {:error, 500, "InternalServerError", "repository commit CID is invalid"}

  defp repo_error({:invalid_block_cid, _reason}),
    do: {:error, 500, "InternalServerError", "repository block CID is invalid"}

  defp repo_error(_reason), do: {:error, 500, "InternalServerError", "repository write failed"}
end
