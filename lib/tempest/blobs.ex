defmodule Tempest.Blobs do
  @moduledoc """
  Blob validation and CID helpers.

  This module is intentionally independent from HTTP handling. Upload routes can
  pass already-read bytes, the declared content length, and the declared MIME
  type through this boundary before inserting metadata or writing storage.
  """

  alias Tempest.Config
  alias Tempest.RepoCore.Cid

  @type validation_error ::
          :blob_too_large
          | :invalid_content_length
          | :content_length_mismatch
          | :missing_mime_type
          | :invalid_mime_type
          | :mime_type_mismatch

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
  defp ensure_mime_match(declared, declared), do: :ok
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
end
