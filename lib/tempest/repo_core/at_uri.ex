defmodule Tempest.RepoCore.AtUri do
  @moduledoc """
  Parser for the current restricted AT URI form used by Lexicons.

  Supported shape:

      at://AUTHORITY[/COLLECTION[/RKEY]]

  Query parameters, fragments, trailing slashes, userinfo, ports, duplicate path
  separators, and additional path segments are rejected. The parser is manual on
  purpose: generic URL parsers commonly misread DID colons in the authority.
  """

  alias Tempest.RepoCore.{Did, Handle, Nsid, RecordKey}

  @enforce_keys [:authority, :authority_type]
  defstruct [:authority, :authority_type, :collection, :rkey]

  @max_length 8 * 1_024

  @type authority_type :: :did | :handle
  @type t :: %__MODULE__{
          authority: String.t(),
          authority_type: authority_type(),
          collection: String.t() | nil,
          rkey: String.t() | nil
        }

  @type error ::
          :invalid_at_uri_syntax
          | :invalid_scheme
          | :invalid_character
          | :missing_authority
          | :not_ascii
          | :too_long
          | :unsupported_query_or_fragment
          | :unsupported_userinfo
          | :trailing_slash
          | :too_many_path_segments
          | {:invalid_authority, term()}
          | {:invalid_collection, term()}
          | {:invalid_record_key, term()}
          | {:not_normalized, :authority | :collection}

  @spec parse(term()) :: {:ok, t()} | {:error, error()}
  def parse(uri) when is_binary(uri) do
    cond do
      byte_size(uri) > @max_length ->
        {:error, :too_long}

      not Tempest.RepoCore.Syntax.ascii?(uri) ->
        {:error, :not_ascii}

      not Tempest.RepoCore.Syntax.visible_ascii?(uri) ->
        {:error, :invalid_character}

      true ->
        parse_ascii(uri)
    end
  end

  def parse(_uri), do: {:error, :invalid_at_uri_syntax}

  @spec parse!(term()) :: t()
  def parse!(uri) do
    case parse(uri) do
      {:ok, parsed} -> parsed
      {:error, reason} -> raise ArgumentError, "invalid AT URI: #{inspect(reason)}"
    end
  end

  @spec valid?(term()) :: boolean()
  def valid?(uri), do: match?({:ok, _uri}, parse(uri))

  @spec record?(t()) :: boolean()
  def record?(%__MODULE__{collection: collection, rkey: rkey}) do
    is_binary(collection) and is_binary(rkey)
  end

  @spec repo_path(t()) :: {:ok, String.t()} | {:error, :not_record_uri}
  def repo_path(%__MODULE__{collection: collection, rkey: rkey}) when is_binary(collection) and is_binary(rkey) do
    {:ok, collection <> "/" <> rkey}
  end

  def repo_path(%__MODULE__{}), do: {:error, :not_record_uri}

  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{} = uri) do
    path =
      case {uri.collection, uri.rkey} do
        {nil, nil} -> ""
        {collection, nil} -> "/" <> collection
        {collection, rkey} -> "/" <> collection <> "/" <> rkey
      end

    "at://" <> uri.authority <> path
  end

  defp parse_ascii("at://" <> rest) do
    cond do
      rest == "" ->
        {:error, :missing_authority}

      String.contains?(rest, ["?", "#"]) ->
        {:error, :unsupported_query_or_fragment}

      String.ends_with?(rest, "/") ->
        {:error, :trailing_slash}

      true ->
        rest
        |> String.split("/")
        |> parse_segments()
    end
  end

  defp parse_ascii(_uri), do: {:error, :invalid_scheme}

  defp parse_segments([authority]) do
    with {:ok, authority, authority_type} <- parse_authority(authority) do
      {:ok, %__MODULE__{authority: authority, authority_type: authority_type}}
    end
  end

  defp parse_segments([authority, collection]) do
    with {:ok, authority, authority_type} <- parse_authority(authority),
         {:ok, collection} <- parse_collection(collection) do
      {:ok,
       %__MODULE__{
         authority: authority,
         authority_type: authority_type,
         collection: collection
       }}
    end
  end

  defp parse_segments([authority, collection, rkey]) do
    with {:ok, authority, authority_type} <- parse_authority(authority),
         {:ok, collection} <- parse_collection(collection),
         {:ok, rkey} <- parse_record_key(rkey) do
      {:ok,
       %__MODULE__{
         authority: authority,
         authority_type: authority_type,
         collection: collection,
         rkey: rkey
       }}
    end
  end

  defp parse_segments(_segments), do: {:error, :too_many_path_segments}

  defp parse_authority(authority) do
    cond do
      authority == "" ->
        {:error, :missing_authority}

      String.contains?(authority, "@") ->
        {:error, :unsupported_userinfo}

      String.starts_with?(authority, "did:") ->
        case Did.parse(authority) do
          {:ok, did} -> {:ok, did, :did}
          {:error, reason} -> {:error, {:invalid_authority, reason}}
        end

      true ->
        case Handle.parse(authority) do
          {:ok, ^authority} -> {:ok, authority, :handle}
          {:ok, _normalized} -> {:error, {:not_normalized, :authority}}
          {:error, reason} -> {:error, {:invalid_authority, reason}}
        end
    end
  end

  defp parse_collection(collection) do
    case Nsid.parse(collection) do
      {:ok, %Nsid{value: ^collection}} -> {:ok, collection}
      {:ok, %Nsid{}} -> {:error, {:not_normalized, :collection}}
      {:error, reason} -> {:error, {:invalid_collection, reason}}
    end
  end

  defp parse_record_key(record_key) do
    case RecordKey.parse(record_key) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, reason} -> {:error, {:invalid_record_key, reason}}
    end
  end
end
