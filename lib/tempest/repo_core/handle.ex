defmodule Tempest.RepoCore.Handle do
  @moduledoc """
  Syntax parser for AT Protocol handles.

  This module validates handle syntax only. Reserved or disallowed TLD policy is
  intentionally kept separate because the official spec distinguishes syntax
  validation from registration and resolution restrictions.
  """

  @max_length 253
  @handle_regex ~r/\A([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\z/

  @type t :: String.t()
  @type error ::
          :invalid_handle_syntax
          | :not_ascii
          | :too_long

  @spec parse(term()) :: {:ok, t()} | {:error, error()}
  def parse(handle) when is_binary(handle) do
    cond do
      byte_size(handle) > @max_length ->
        {:error, :too_long}

      not Tempest.RepoCore.Syntax.ascii?(handle) ->
        {:error, :not_ascii}

      Regex.match?(@handle_regex, handle) ->
        {:ok, String.downcase(handle)}

      true ->
        {:error, :invalid_handle_syntax}
    end
  end

  def parse(_handle), do: {:error, :invalid_handle_syntax}

  @spec parse!(term()) :: t()
  def parse!(handle) do
    case parse(handle) do
      {:ok, parsed} -> parsed
      {:error, reason} -> raise ArgumentError, "invalid handle: #{inspect(reason)}"
    end
  end

  @spec valid?(term()) :: boolean()
  def valid?(handle), do: match?({:ok, _handle}, parse(handle))
end
