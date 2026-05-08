defmodule Tempest.RepoCore.Tid do
  @moduledoc """
  Parser and constructor for AT Protocol timestamp identifiers.
  """

  import Kernel, except: [to_string: 1]
  import Bitwise

  @alphabet "234567abcdefghijklmnopqrstuvwxyz"
  @max_unix_microseconds 0x1F_FFFF_FFFF_FFFF
  @max_clock_id 0x3FF
  @tid_regex ~r/\A[234567abcdefghij][234567abcdefghijklmnopqrstuvwxyz]{12}\z/

  @enforce_keys [:value, :integer, :unix_microseconds, :clock_id]
  defstruct [:value, :integer, :unix_microseconds, :clock_id]

  @type t :: %__MODULE__{
          value: String.t(),
          integer: non_neg_integer(),
          unix_microseconds: non_neg_integer(),
          clock_id: 0..1023
        }

  @type error ::
          :invalid_tid_syntax
          | :not_ascii
          | :timestamp_out_of_range
          | :clock_id_out_of_range
          | :integer_out_of_range

  @spec parse(term()) :: {:ok, t()} | {:error, error()}
  def parse(tid) when is_binary(tid) do
    cond do
      not Tempest.RepoCore.Syntax.ascii?(tid) ->
        {:error, :not_ascii}

      not Regex.match?(@tid_regex, tid) ->
        {:error, :invalid_tid_syntax}

      true ->
        integer = decode_integer!(tid)
        {:ok, from_integer_unchecked(integer, tid)}
    end
  end

  def parse(_tid), do: {:error, :invalid_tid_syntax}

  @spec parse!(term()) :: t()
  def parse!(tid) do
    case parse(tid) do
      {:ok, parsed} -> parsed
      {:error, reason} -> raise ArgumentError, "invalid TID: #{inspect(reason)}"
    end
  end

  @spec valid?(term()) :: boolean()
  def valid?(tid), do: match?({:ok, _tid}, parse(tid))

  @spec new(non_neg_integer(), 0..1023) :: {:ok, t()} | {:error, error()}
  def new(unix_microseconds, clock_id)
      when is_integer(unix_microseconds) and is_integer(clock_id) do
    cond do
      unix_microseconds not in 0..@max_unix_microseconds ->
        {:error, :timestamp_out_of_range}

      clock_id not in 0..@max_clock_id ->
        {:error, :clock_id_out_of_range}

      true ->
        integer = unix_microseconds <<< 10 ||| clock_id
        from_integer(integer)
    end
  end

  def new(_unix_microseconds, _clock_id), do: {:error, :invalid_tid_syntax}

  @spec new!(non_neg_integer(), 0..1023) :: t()
  def new!(unix_microseconds, clock_id) do
    case new(unix_microseconds, clock_id) do
      {:ok, tid} -> tid
      {:error, reason} -> raise ArgumentError, "invalid TID parts: #{inspect(reason)}"
    end
  end

  @spec from_integer(non_neg_integer()) :: {:ok, t()} | {:error, error()}
  def from_integer(integer) when is_integer(integer) and integer in 0..0x7FFF_FFFF_FFFF_FFFF do
    value = encode_integer(integer)
    {:ok, from_integer_unchecked(integer, value)}
  end

  def from_integer(_integer), do: {:error, :integer_out_of_range}

  @spec from_integer!(non_neg_integer()) :: t()
  def from_integer!(integer) do
    case from_integer(integer) do
      {:ok, tid} -> tid
      {:error, reason} -> raise ArgumentError, "invalid TID integer: #{inspect(reason)}"
    end
  end

  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{value: value}), do: value

  @spec now_unix_microseconds() :: non_neg_integer()
  def now_unix_microseconds do
    System.os_time(:microsecond)
  end

  @spec max_unix_microseconds() :: non_neg_integer()
  def max_unix_microseconds, do: @max_unix_microseconds

  @spec max_clock_id() :: non_neg_integer()
  def max_clock_id, do: @max_clock_id

  defp from_integer_unchecked(integer, value) do
    %__MODULE__{
      value: value,
      integer: integer,
      unix_microseconds: integer >>> 10 &&& @max_unix_microseconds,
      clock_id: integer &&& @max_clock_id
    }
  end

  defp encode_integer(integer) do
    chars =
      12..0//-1
      |> Enum.map(fn index ->
        alphabet_at(integer >>> (index * 5) &&& 0x1F)
      end)

    IO.iodata_to_binary(chars)
  end

  defp decode_integer!(tid) do
    tid
    |> :binary.bin_to_list()
    |> Enum.reduce(0, fn char, integer ->
      integer <<< 5 ||| alphabet_index!(char)
    end)
  end

  defp alphabet_at(index), do: :binary.at(@alphabet, index)

  defp alphabet_index!(char) do
    case :binary.match(@alphabet, <<char>>) do
      {index, 1} -> index
    end
  end
end
