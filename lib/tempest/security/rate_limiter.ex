defmodule Tempest.Security.RateLimiter do
  @moduledoc """
  Small in-memory rate limiter for auth and security endpoints.

  This is intentionally local-node state. It is enough for the single-node target
  and keeps callers honest until a persistent/distributed limiter is justified.
  """

  @table :tempest_rate_limits

  def check(bucket, key, opts \\ []) when is_atom(bucket) and is_binary(key) do
    table = table()
    now = System.monotonic_time(:millisecond)
    limit = Keyword.get(opts, :limit, default_limit(bucket))
    window_ms = Keyword.get(opts, :window_ms, default_window_ms(bucket))
    id = {bucket, key}

    hits =
      table
      |> :ets.lookup(id)
      |> case do
        [{^id, hits}] -> Enum.filter(hits, &(now - &1 < window_ms))
        [] -> []
      end

    if length(hits) >= limit do
      {:error, :rate_limited}
    else
      :ets.insert(table, {id, [now | hits]})
      :ok
    end
  end

  def reset! do
    case :ets.whereis(@table) do
      :undefined -> :ok
      _tid -> :ets.delete_all_objects(@table)
    end
  end

  defp table do
    case :ets.whereis(@table) do
      :undefined ->
        try do
          :ets.new(@table, [:named_table, :public, :set])
        rescue
          ArgumentError -> @table
        end

      _tid ->
        @table
    end
  end

  defp default_limit(:login), do: 10
  defp default_limit(:oauth), do: 30
  defp default_limit(:app_password), do: 10
  defp default_limit(:email), do: 5
  defp default_limit(:totp), do: 8
  defp default_limit(_bucket), do: 20

  defp default_window_ms(_bucket), do: 60_000
end
