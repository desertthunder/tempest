defmodule Tempest.Sequencer do
  @moduledoc """
  Minimal sequencer write boundary for placeholder events.
  """

  alias Exqlite.Sqlite3
  alias Tempest.Storage.Timestamp

  @insert_sql """
  INSERT INTO repo_seq (did, event_type, event_cbor, created_at)
  VALUES (?1, ?2, ?3, ?4)
  """

  @insert_repo_commit_sql """
  INSERT INTO repo_seq (did, event_type, rev, commit_cid, event_cbor, created_at)
  VALUES (?1, ?2, ?3, ?4, ?5, ?6)
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
         :ok <- Sqlite3.bind(statement, [did, event_type, event, Timestamp.iso8601_utc()]),
         :done <- Sqlite3.step(conn, statement),
         :ok <- Sqlite3.release(conn, statement),
         :ok <- Sqlite3.close(conn) do
      :ok
    else
      {:error, reason} -> {:error, reason}
      other -> {:error, other}
    end
  end

  def insert_repo_commit(did, rev, commit_cid, event_type, payload \\ %{})
      when is_binary(did) and is_binary(rev) and is_binary(commit_cid) and is_binary(event_type) do
    path =
      Tempest.Config.load!()
      |> Tempest.Config.sequencer_db_path()

    event =
      payload
      |> Map.put("placeholder", true)
      |> Jason.encode!()

    with {:ok, conn} <- Sqlite3.open(path),
         {:ok, statement} <- Sqlite3.prepare(conn, @insert_repo_commit_sql),
         :ok <- Sqlite3.bind(statement, [did, event_type, rev, commit_cid, event, Timestamp.iso8601_utc()]),
         :done <- Sqlite3.step(conn, statement),
         :ok <- Sqlite3.release(conn, statement),
         :ok <- Sqlite3.close(conn) do
      :ok
    else
      {:error, reason} -> {:error, reason}
      other -> {:error, other}
    end
  end
end
