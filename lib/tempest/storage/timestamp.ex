defmodule Tempest.Storage.Timestamp do
  @moduledoc """
  Timestamp helpers for persisted storage rows.
  """

  def iso8601_utc do
    DateTime.utc_now()
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
  end
end
