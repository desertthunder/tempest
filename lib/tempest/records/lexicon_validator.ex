defmodule Tempest.Records.LexiconValidator do
  @moduledoc """
  Validation boundary for repository record writes.
  """

  alias Tempest.Lexicon.Validator
  alias Tempest.RepoCore.{Cid, Nsid, RecordKey}

  @type create_input :: %{
          repo: String.t(),
          collection: String.t(),
          rkey: String.t() | nil,
          record: map(),
          swap_commit: String.t() | nil,
          validate: boolean() | nil
        }

  def validate_create_record_input(params) when is_map(params) do
    with {:ok, repo} <- fetch_string(params, "repo"),
         {:ok, collection} <- validate_collection(Map.get(params, "collection")),
         {:ok, rkey} <- validate_optional_rkey(Map.get(params, "rkey")),
         {:ok, record} <- fetch_record(params),
         {:ok, swap_commit} <- validate_optional_cid(Map.get(params, "swapCommit")),
         {:ok, validate} <- validate_optional_boolean(Map.get(params, "validate")) do
      {:ok,
       %{
         repo: repo,
         collection: collection,
         rkey: rkey,
         record: record,
         swap_commit: swap_commit,
         validate: validate
       }}
    end
  end

  def validate_create_record_input(_params), do: {:error, :invalid_request_body}

  def validate_record(collection, rkey, record, validate) do
    Validator.validate_record(collection, rkey, record,
      validate_schema?: validate != false,
      require_schema?: validate == true
    )
    |> case do
      {:ok, status} -> {:ok, Atom.to_string(status)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_string(params, key) do
    case Map.get(params, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _value -> {:error, {:missing_field, key}}
    end
  end

  defp validate_collection(collection) do
    with value when is_binary(value) and value != "" <- collection,
         {:ok, %Nsid{value: ^value}} <- Nsid.parse(value) do
      {:ok, value}
    else
      _error -> {:error, :invalid_collection}
    end
  end

  defp validate_optional_rkey(nil), do: {:ok, nil}

  defp validate_optional_rkey(rkey) do
    case RecordKey.parse(rkey) do
      {:ok, rkey} -> {:ok, rkey}
      {:error, _reason} -> {:error, :invalid_rkey}
    end
  end

  defp fetch_record(params) do
    case Map.get(params, "record") do
      record when is_map(record) -> {:ok, record}
      _value -> {:error, {:missing_field, "record"}}
    end
  end

  defp validate_optional_cid(nil), do: {:ok, nil}

  defp validate_optional_cid(cid) do
    case Cid.parse(cid) do
      {:ok, _cid} -> {:ok, cid}
      {:error, _reason} -> {:error, :invalid_swap_commit}
    end
  end

  defp validate_optional_boolean(nil), do: {:ok, nil}
  defp validate_optional_boolean(value) when is_boolean(value), do: {:ok, value}
  defp validate_optional_boolean(_value), do: {:error, :invalid_validate}
end
