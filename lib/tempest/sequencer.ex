defmodule Tempest.Sequencer do
  @moduledoc """
  Minimal sequencer write boundary for placeholder events.
  """

  alias Exqlite.Sqlite3

  @insert_sql """
  INSERT INTO repo_seq (did, event_type, event_cbor, created_at)
  VALUES (?1, ?2, ?3, ?4)
  """

  def insert_placeholder(did, event_type, payload \\ %{}) when is_binary(did) and is_binary(event_type) do
    path =
      Tempest.Config.load!()
      |> Tempest.Config.sequencer_db_path()

    event =
      payload
      |> Map.put("placeholder", true)
      |> Jason.encode!()

    with {:ok, conn} <- Sqlite3.open(path),
         {:ok, statement} <- Sqlite3.prepare(conn, @insert_sql),
         :ok <- Sqlite3.bind(statement, [did, event_type, event, timestamp()]),
         :done <- Sqlite3.step(conn, statement),
         :ok <- Sqlite3.release(conn, statement),
         :ok <- Sqlite3.close(conn) do
      :ok
    else
      {:error, reason} -> {:error, reason}
      other -> {:error, other}
    end
  end

  defp timestamp do
    DateTime.utc_now()
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
  end
end
