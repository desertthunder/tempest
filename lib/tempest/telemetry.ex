defmodule Tempest.Telemetry do
  @moduledoc """
  Small helpers for Tempest telemetry events.
  """

  def execute(event, measurements, metadata \\ %{}) when is_list(event) and is_map(measurements) and is_map(metadata) do
    :telemetry.execute([:tempest | event], measurements, metadata)
  end

  def timed(event, metadata, fun) when is_function(fun, 0) do
    start = System.monotonic_time()
    result = fun.()
    duration = System.monotonic_time() - start
    execute(event, %{count: 1, duration: duration}, Map.put(metadata, :status, status(result)))
    result
  end

  defp status({:ok, _value}), do: :ok
  defp status({:error, _status, _error, _message}), do: :error
  defp status({:error, _reason}), do: :error
  defp status(_other), do: :ok
end
