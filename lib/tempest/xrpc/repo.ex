defmodule Tempest.Xrpc.Repo do
  @moduledoc """
  Handlers for `com.atproto.repo.*` XRPC methods.
  """

  alias Plug.Conn
  alias Tempest.Blobs
  alias Tempest.Blobs.LocalStorage
  alias Tempest.Config
  alias Tempest.Records

  def upload_blob(conn, _params, _method) do
    config = Config.load!()

    with {:ok, declared_size} <- content_length(conn),
         {:ok, declared_mime_type} <- content_type(conn),
         {:ok, bytes, conn} <- read_upload_body(conn, config.blob_max_bytes),
         {:ok, metadata} <- Blobs.validate_upload(bytes, declared_size, declared_mime_type, config),
         {:ok, _stored} <-
           LocalStorage.put_temp_blob(config, conn.assigns.auth_context.account.did, metadata.cid, bytes),
         :ok <- Blobs.put_temp_metadata(conn.assigns.auth_context.account.did, metadata) do
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
  defp repo_error(:invalid_limit), do: {:error, 400, "InvalidRequest", "limit must be between 1 and 100"}
  defp repo_error(:invalid_reverse), do: {:error, 400, "InvalidRequest", "reverse must be a boolean"}
  defp repo_error(:invalid_swap_record), do: {:error, 400, "InvalidRequest", "swapRecord is invalid"}
  defp repo_error(:invalid_swap_commit), do: {:error, 400, "InvalidRequest", "swapCommit is invalid"}
  defp repo_error(:invalid_validate), do: {:error, 400, "InvalidRequest", "validate must be a boolean"}
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
  defp repo_error(:missing_signing_key), do: {:error, 500, "InternalServerError", "account has no active signing key"}
  defp repo_error({:field_too_small, field}), do: {:error, 400, "InvalidRequest", "#{field} is too small"}
  defp repo_error({:field_too_large, field}), do: {:error, 400, "InvalidRequest", "#{field} is too large"}

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

  defp repo_error(_reason), do: {:error, 500, "InternalServerError", "repository write failed"}
end
