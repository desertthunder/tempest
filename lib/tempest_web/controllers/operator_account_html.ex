defmodule TempestWeb.OperatorAccountHTML do
  use TempestWeb, :html

  embed_templates "operator_account_html/*"

  attr :section, :atom, default: nil

  def account_nav(assigns) do
    ~H"""
    <nav class="resource-strip operator-account__nav" aria-label="Operator account tools">
      <a href={~p"/account"}>Dashboard</a>
      <a href={~p"/account/repo"}>Repo</a>
      <a href={~p"/account/blobs"}>Blobs</a>
      <a href={~p"/account/access"}>Access</a>
      <a href={~p"/account/security"}>Security</a>
      <a href={~p"/account/migration"}>Migration</a>
      <a href={~p"/account/sequencer"}>Sequencer</a>
      <a href={~p"/account/firehose"}>Firehose</a>
    </nav>
    """
  end

  def json_pretty(value), do: value |> json_safe() |> Jason.encode!(pretty: true)

  def status_value(nil), do: "active"
  def status_value(%{revoked_at: revoked}) when not is_nil(revoked), do: "revoked"
  def status_value(%{rotated_at: rotated}) when not is_nil(rotated), do: "rotated"
  def status_value(%{disabled_at: disabled}) when not is_nil(disabled), do: "disabled"
  def status_value(%{confirmed_at: nil}), do: "pending"
  def status_value(_record), do: "active"

  def present(nil), do: "—"
  def present(value), do: to_string(value)

  defp json_safe(%Tempest.RepoCore.Drisl.Bytes{bytes: bytes}), do: %{"$bytes" => Base.encode64(bytes)}
  defp json_safe(value) when is_map(value), do: Map.new(value, fn {key, value} -> {key, json_safe(value)} end)
  defp json_safe(value) when is_list(value), do: Enum.map(value, &json_safe/1)
  defp json_safe(value), do: value
end
