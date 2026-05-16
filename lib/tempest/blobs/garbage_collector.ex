defmodule Tempest.Blobs.GarbageCollector do
  @moduledoc """
  Periodically removes expired temporary blobs.
  """

  use GenServer

  alias Tempest.Blobs
  alias Tempest.Config

  @default_interval_ms 60 * 60 * 1000

  @doc """
  Starts the garbage collector unless disabled by configuration.
  """
  def start_link(opts \\ []) do
    if Keyword.get(config(), :enabled?, true) do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    else
      :ignore
    end
  end

  @doc """
  Runs one garbage collection pass.
  """
  @spec run_once(Config.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  def run_once(%Config{} = config \\ Config.load!()) do
    Blobs.delete_expired_temp(config, DateTime.utc_now())
  end

  @impl true
  def init(_opts) do
    state = %{config: Config.load!(), interval_ms: interval_ms()}
    schedule_next(state.interval_ms)
    {:ok, state}
  end

  @impl true
  def handle_info(:collect, state) do
    _result = run_once(state.config)
    schedule_next(state.interval_ms)
    {:noreply, state}
  end

  defp schedule_next(interval_ms), do: Process.send_after(self(), :collect, interval_ms)

  defp interval_ms do
    config()
    |> Keyword.get(:interval_ms, @default_interval_ms)
    |> max(60_000)
  end

  defp config do
    Application.get_env(:tempest, __MODULE__, [])
  end
end
