defmodule TempestWeb.OperatorAccountHTML do
  use TempestWeb, :html

  embed_templates "operator_account_html/*"

  def json_pretty(value), do: value |> json_safe() |> Jason.encode!(pretty: true)

  defp json_safe(%Tempest.RepoCore.Drisl.Bytes{bytes: bytes}), do: %{"$bytes" => Base.encode64(bytes)}
  defp json_safe(value) when is_map(value), do: Map.new(value, fn {key, value} -> {key, json_safe(value)} end)
  defp json_safe(value) when is_list(value), do: Enum.map(value, &json_safe/1)
  defp json_safe(value), do: value
end
