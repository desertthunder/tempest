defmodule Tempest.Xrpc.Repo do
  @moduledoc """
  Handlers for `com.atproto.repo.*` XRPC methods.
  """

  alias Tempest.Records

  def create_record(conn, params, _method) do
    case Records.create_record(conn.assigns.auth_context, params) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> repo_error(reason)
    end
  end

  defp repo_error(:duplicate_record), do: {:error, 409, "InvalidRequest", "record already exists"}
  defp repo_error(:invalid_swap), do: {:error, 409, "InvalidSwap", "swapCommit does not match current commit"}
  defp repo_error(:repo_mismatch), do: {:error, 400, "InvalidRequest", "repo must match the authenticated account"}
  defp repo_error(:invalid_collection), do: {:error, 400, "InvalidRequest", "collection is invalid"}
  defp repo_error(:invalid_rkey), do: {:error, 400, "InvalidRequest", "rkey is invalid"}
  defp repo_error(:invalid_swap_commit), do: {:error, 400, "InvalidRequest", "swapCommit is invalid"}
  defp repo_error(:invalid_validate), do: {:error, 400, "InvalidRequest", "validate must be a boolean"}
  defp repo_error(:missing_record_type), do: {:error, 400, "InvalidRequest", "record must include a $type field"}
  defp repo_error(:record_type_mismatch), do: {:error, 400, "InvalidRequest", "record $type must match collection"}
  defp repo_error(:unknown_lexicon), do: {:error, 400, "InvalidRequest", "record lexicon is unknown"}
  defp repo_error(:missing_signing_key), do: {:error, 500, "InternalServerError", "account has no active signing key"}

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
