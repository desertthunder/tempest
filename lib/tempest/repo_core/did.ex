defmodule Tempest.RepoCore.Did do
  @moduledoc """
  Syntax parser for AT Protocol DID identifiers.

  This validates the generic atproto DID syntax. It intentionally accepts
  syntactically valid DIDs with unsupported methods; method support is a
  resolution/runtime policy, not a parser concern.
  """

  @supported_methods ~w(plc web)
  @max_length 2_048
  @did_regex ~r/\Adid:[a-z]+:[A-Za-z0-9._:%-]*[A-Za-z0-9._-]\z/

  @type t :: String.t()
  @type error ::
          :invalid_did_syntax
          | :not_ascii
          | :too_long

  @spec parse(term()) :: {:ok, t()} | {:error, error()}
  def parse(did) when is_binary(did) do
    cond do
      byte_size(did) > @max_length ->
        {:error, :too_long}

      not Tempest.RepoCore.Syntax.ascii?(did) ->
        {:error, :not_ascii}

      Regex.match?(@did_regex, did) ->
        {:ok, did}

      true ->
        {:error, :invalid_did_syntax}
    end
  end

  def parse(_did), do: {:error, :invalid_did_syntax}

  @spec parse!(term()) :: t()
  def parse!(did) do
    case parse(did) do
      {:ok, parsed} -> parsed
      {:error, reason} -> raise ArgumentError, "invalid DID: #{inspect(reason)}"
    end
  end

  @spec valid?(term()) :: boolean()
  def valid?(did), do: match?({:ok, _did}, parse(did))

  @spec supported_method?(t()) :: boolean()
  def supported_method?(did) when is_binary(did) do
    case Regex.run(~r/\Adid:([a-z]+):/, did) do
      [_, method] -> method in @supported_methods
      _other -> false
    end
  end

  def supported_method?(_did), do: false
end
