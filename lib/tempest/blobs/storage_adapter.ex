defmodule Tempest.Blobs.StorageAdapter do
  @moduledoc """
  Blob storage adapter contract.

  Local metadata remains authoritative; adapters only own bytes.
  """

  @type config :: term()
  @type blob_read :: %{bytes: binary(), content_length: non_neg_integer(), mime_type: String.t()}

  @callback put_temp_blob(config(), String.t(), String.t(), binary()) ::
              {:ok, %{cid: String.t(), path: String.t(), size: non_neg_integer()}} | {:error, term()}

  @callback promote_blob(config(), String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}

  @callback get_blob(config(), String.t(), String.t(), String.t()) :: {:ok, blob_read()} | {:error, term()}

  @callback delete_blob(config(), String.t(), String.t()) :: :ok | {:error, term()}

  @callback delete_temp_blob(config(), String.t(), String.t()) :: :ok | {:error, term()}

  @callback list_blobs(config(), String.t(), keyword()) ::
              {:ok, %{required(:cids) => [String.t()], optional(:cursor) => String.t()}} | {:error, term()}
end
