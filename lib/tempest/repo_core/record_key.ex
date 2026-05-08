defmodule Tempest.RepoCore.RecordKey do
  @moduledoc """
  Syntax parser for AT Protocol record keys.
  """

  @max_length 512
  @record_key_regex ~r/\A[A-Za-z0-9.\-_:~]+\z/

  @type t :: String.t()
  @type error ::
          :invalid_record_key_syntax
          | :not_ascii
          | :too_long

  @spec parse(term()) :: {:ok, t()} | {:error, error()}
  def parse(record_key) when is_binary(record_key) do
    cond do
      byte_size(record_key) > @max_length ->
        {:error, :too_long}

      not Tempest.RepoCore.Syntax.ascii?(record_key) ->
        {:error, :not_ascii}

      record_key in [".", ".."] ->
        {:error, :invalid_record_key_syntax}

      Regex.match?(@record_key_regex, record_key) ->
        {:ok, record_key}

      true ->
        {:error, :invalid_record_key_syntax}
    end
  end

  def parse(_record_key), do: {:error, :invalid_record_key_syntax}

  @spec parse!(term()) :: t()
  def parse!(record_key) do
    case parse(record_key) do
      {:ok, parsed} -> parsed
      {:error, reason} -> raise ArgumentError, "invalid record key: #{inspect(reason)}"
    end
  end

  @spec valid?(term()) :: boolean()
  def valid?(record_key), do: match?({:ok, _record_key}, parse(record_key))
end
