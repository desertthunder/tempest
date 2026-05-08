defmodule Tempest.RepoCore.Tid.Clock do
  @moduledoc """
  Concurrent TID generator with a monotonic guard per DID.
  """

  use GenServer

  alias Tempest.RepoCore.{Did, Tid}

  @type error ::
          {:invalid_did, term()}
          | :timestamp_out_of_range
          | :clock_id_out_of_range

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name)
    clock_id = Keyword.get_lazy(opts, :clock_id, &random_clock_id/0)

    genserver_opts = if name, do: [name: name], else: []
    GenServer.start_link(__MODULE__, %{clock_id: clock_id}, genserver_opts)
  end

  @spec next(GenServer.server(), String.t(), keyword()) :: {:ok, Tid.t()} | {:error, error()}
  def next(clock, did, opts \\ []) do
    GenServer.call(clock, {:next, did, opts})
  end

  @spec random_clock_id() :: non_neg_integer()
  def random_clock_id do
    <<value::16>> = :crypto.strong_rand_bytes(2)
    rem(value, Tid.max_clock_id() + 1)
  end

  @impl GenServer
  def init(%{clock_id: clock_id}) do
    if clock_id in 0..Tid.max_clock_id() do
      {:ok, %{clock_id: clock_id, last_by_did: %{}}}
    else
      {:stop, :clock_id_out_of_range}
    end
  end

  @impl GenServer
  def handle_call({:next, did, opts}, _from, state) do
    with {:ok, did} <- parse_did(did),
         {:ok, now} <- now_unix_microseconds(opts),
         {:ok, next_microsecond} <- next_microsecond(now, Map.get(state.last_by_did, did)),
         {:ok, tid} <- Tid.new(next_microsecond, state.clock_id) do
      state = put_in(state.last_by_did[did], next_microsecond)
      {:reply, {:ok, tid}, state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  defp parse_did(did) do
    case Did.parse(did) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, reason} -> {:error, {:invalid_did, reason}}
    end
  end

  defp now_unix_microseconds(opts) do
    now = Keyword.get_lazy(opts, :now_unix_microseconds, &Tid.now_unix_microseconds/0)

    if is_integer(now) and now in 0..Tid.max_unix_microseconds() do
      {:ok, now}
    else
      {:error, :timestamp_out_of_range}
    end
  end

  defp next_microsecond(now, nil), do: {:ok, now}

  defp next_microsecond(now, last) when now > last, do: {:ok, now}

  defp next_microsecond(_now, last) do
    if last < Tid.max_unix_microseconds() do
      {:ok, last + 1}
    else
      {:error, :timestamp_out_of_range}
    end
  end
end
