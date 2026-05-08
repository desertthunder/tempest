defmodule Tempest.RepoCore.Nsid do
  @moduledoc """
  Syntax parser for AT Protocol namespaced identifiers.
  """

  @enforce_keys [:value, :authority, :name]
  defstruct [:value, :authority, :name]

  @max_length 317
  @type t :: %__MODULE__{
          value: String.t(),
          authority: String.t(),
          name: String.t()
        }

  @type error ::
          :invalid_nsid_syntax
          | :not_ascii
          | :too_long

  @spec parse(term()) :: {:ok, t()} | {:error, error()}
  def parse(nsid) when is_binary(nsid) do
    cond do
      byte_size(nsid) > @max_length ->
        {:error, :too_long}

      not Tempest.RepoCore.Syntax.ascii?(nsid) ->
        {:error, :not_ascii}

      true ->
        parse_ascii(nsid)
    end
  end

  def parse(_nsid), do: {:error, :invalid_nsid_syntax}

  @spec parse!(term()) :: t()
  def parse!(nsid) do
    case parse(nsid) do
      {:ok, parsed} -> parsed
      {:error, reason} -> raise ArgumentError, "invalid NSID: #{inspect(reason)}"
    end
  end

  @spec valid?(term()) :: boolean()
  def valid?(nsid), do: match?({:ok, _nsid}, parse(nsid))

  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{value: value}), do: value

  defp parse_ascii(nsid) do
    segments = String.split(nsid, ".")

    with :ok <- validate_segment_count(segments),
         {name, authority_segments} <- pop_name(segments),
         :ok <- validate_name(name),
         :ok <- validate_authority_segments(authority_segments) do
      normalized_authority_segments = Enum.map(authority_segments, &String.downcase/1)

      authority =
        normalized_authority_segments
        |> Enum.reverse()
        |> Enum.join(".")

      value =
        normalized_authority_segments
        |> Kernel.++([name])
        |> Enum.join(".")

      {:ok, %__MODULE__{value: value, authority: authority, name: name}}
    end
  end

  defp validate_segment_count(segments) do
    if length(segments) >= 3 do
      :ok
    else
      {:error, :invalid_nsid_syntax}
    end
  end

  defp pop_name(segments) do
    [name | authority_segments] = Enum.reverse(segments)
    {name, Enum.reverse(authority_segments)}
  end

  defp validate_authority_segments([first | _rest] = segments) do
    cond do
      byte_size(Enum.join(segments, ".")) > 253 ->
        {:error, :invalid_nsid_syntax}

      String.match?(first, ~r/\A[0-9]/) ->
        {:error, :invalid_nsid_syntax}

      Enum.all?(segments, &valid_authority_segment?/1) ->
        :ok

      true ->
        {:error, :invalid_nsid_syntax}
    end
  end

  defp validate_authority_segments(_segments), do: {:error, :invalid_nsid_syntax}

  defp valid_authority_segment?(segment) do
    byte_size(segment) in 1..63 and
      String.match?(segment, ~r/\A[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\z/)
  end

  defp validate_name(name) do
    if byte_size(name) in 1..63 and String.match?(name, ~r/\A[a-zA-Z][a-zA-Z0-9]{0,62}\z/) do
      :ok
    else
      {:error, :invalid_nsid_syntax}
    end
  end
end
