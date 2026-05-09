defmodule Tempest.Sequencer do
  @moduledoc """
  Durable PDS-wide event sequence for sync/firehose consumers.

  `repo_seq` is the source of truth. Live fanout can happen after this boundary,
  but callers should only treat an event as visible once the durable insert
  returns a concrete monotonic `seq`.
  """

  alias Exqlite.Sqlite3
  alias Tempest.RepoCore.Drisl
  alias Tempest.Storage.Timestamp

  @identity "#identity"
  @account "#account"
  @commit "#commit"
  @topic "firehose:repo_seq"

  @insert_sql """
  INSERT INTO repo_seq (did, event_type, rev, commit_cid, event_cbor, created_at)
  VALUES (?1, ?2, ?3, ?4, ?5, ?6)
  """

  @update_event_sql "UPDATE repo_seq SET event_cbor = ?1 WHERE seq = ?2"
  @last_insert_sql "SELECT last_insert_rowid()"
  @current_seq_sql "SELECT COALESCE(MAX(seq), 0) FROM repo_seq"

  defmodule Event do
    @moduledoc """
    Event returned after a durable sequencer insert.
    """

    @enforce_keys [:seq, :did, :event_type, :payload, :event_cbor, :created_at]
    defstruct [:seq, :did, :event_type, :rev, :commit_cid, :payload, :event_cbor, :created_at]
  end

  def topic, do: @topic

  def subscribe do
    Phoenix.PubSub.subscribe(Tempest.PubSub, @topic)
  end

  def insert_identity_event(did, action, payload \\ %{}) do
    insert_event(did, @identity, action, payload)
  end

  def insert_account_event(did, action, payload \\ %{}) do
    insert_event(did, @account, action, payload)
  end

  def insert_repo_commit(did, rev, commit_cid, action, payload \\ %{})
      when is_binary(did) and is_binary(rev) and is_binary(commit_cid) and is_binary(action) do
    payload =
      payload
      |> normalize_payload()
      |> Map.merge(%{
        "rev" => rev,
        "commit" => commit_cid
      })

    insert_event(did, @commit, action, payload, rev: rev, commit_cid: commit_cid)
  end

  def list_after(cursor, opts \\ []) when is_integer(cursor) and cursor >= 0 do
    limit = Keyword.get(opts, :limit, 500)
    did = Keyword.get(opts, :did)

    path =
      Tempest.Config.load!()
      |> Tempest.Config.sequencer_db_path()

    {sql, bindings} = list_after_query(cursor, limit, did)

    with {:ok, conn} <- Sqlite3.open(path),
         {:ok, statement} <- Sqlite3.prepare(conn, sql),
         :ok <- Sqlite3.bind(statement, bindings),
         {:ok, rows} <- Sqlite3.fetch_all(conn, statement),
         :ok <- Sqlite3.release(conn, statement),
         :ok <- Sqlite3.close(conn) do
      {:ok, Enum.map(rows, &event_from_row/1)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def current_seq do
    path =
      Tempest.Config.load!()
      |> Tempest.Config.sequencer_db_path()

    with {:ok, conn} <- Sqlite3.open(path),
         {:ok, statement} <- Sqlite3.prepare(conn, @current_seq_sql),
         {:ok, [[seq]]} <- Sqlite3.fetch_all(conn, statement),
         :ok <- Sqlite3.release(conn, statement),
         :ok <- Sqlite3.close(conn) do
      {:ok, seq}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp list_after_query(cursor, limit, did) when is_binary(did) do
    {"""
     SELECT seq, did, event_type, rev, commit_cid, event_cbor, created_at
     FROM repo_seq
     WHERE seq > ?1 AND did = ?2 AND event_type IN ('#identity', '#account', '#commit')
     ORDER BY seq ASC
     LIMIT ?3
     """, [cursor, did, limit]}
  end

  defp list_after_query(cursor, limit, _did) do
    {"""
     SELECT seq, did, event_type, rev, commit_cid, event_cbor, created_at
     FROM repo_seq
     WHERE seq > ?1 AND event_type IN ('#identity', '#account', '#commit')
     ORDER BY seq ASC
     LIMIT ?2
     """, [cursor, limit]}
  end

  defp insert_event(did, event_type, action, payload, opts \\ [])
       when is_binary(did) and is_binary(event_type) and is_binary(action) and is_map(payload) do
    path =
      Tempest.Config.load!()
      |> Tempest.Config.sequencer_db_path()

    created_at = Timestamp.iso8601_utc()
    rev = Keyword.get(opts, :rev)
    commit_cid = Keyword.get(opts, :commit_cid)
    payload = normalize_payload(payload)

    with {:ok, conn} <- Sqlite3.open(path) do
      result = transact_insert_event(conn, did, event_type, action, payload, rev, commit_cid, created_at)

      case Sqlite3.close(conn) do
        :ok -> broadcast_insert(result)
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp broadcast_insert({:ok, %Event{} = event}) do
    :ok = Phoenix.PubSub.broadcast(Tempest.PubSub, @topic, {:tempest_firehose_event, event})
    {:ok, event}
  end

  defp broadcast_insert(result), do: result

  defp transact_insert_event(conn, did, event_type, action, payload, rev, commit_cid, created_at) do
    result =
      with :ok <- Sqlite3.execute(conn, "BEGIN IMMEDIATE"),
           {:ok, seq} <- insert_empty_event(conn, did, event_type, rev, commit_cid, created_at),
           event_payload <- build_payload(seq, did, event_type, action, payload, rev, commit_cid, created_at),
           {:ok, event_cbor} <- Drisl.encode(event_payload),
           :ok <- update_event_cbor(conn, seq, event_cbor),
           :ok <- Sqlite3.execute(conn, "COMMIT") do
        {:ok,
         %Event{
           seq: seq,
           did: did,
           event_type: event_type,
           rev: rev,
           commit_cid: commit_cid,
           payload: event_payload,
           event_cbor: event_cbor,
           created_at: created_at
         }}
      end

    case result do
      {:ok, _event} ->
        result

      {:error, _reason} ->
        _ = Sqlite3.execute(conn, "ROLLBACK")
        result

      other ->
        _ = Sqlite3.execute(conn, "ROLLBACK")
        {:error, other}
    end
  end

  defp insert_empty_event(conn, did, event_type, rev, commit_cid, created_at) do
    with {:ok, statement} <- Sqlite3.prepare(conn, @insert_sql),
         :ok <- Sqlite3.bind(statement, [did, event_type, rev, commit_cid, "", created_at]),
         :done <- Sqlite3.step(conn, statement),
         :ok <- Sqlite3.release(conn, statement),
         {:ok, seq} <- last_insert_rowid(conn) do
      {:ok, seq}
    end
  end

  defp last_insert_rowid(conn) do
    with {:ok, statement} <- Sqlite3.prepare(conn, @last_insert_sql),
         {:ok, [[seq]]} <- Sqlite3.fetch_all(conn, statement),
         :ok <- Sqlite3.release(conn, statement) do
      {:ok, seq}
    end
  end

  defp update_event_cbor(conn, seq, event_cbor) do
    with {:ok, statement} <- Sqlite3.prepare(conn, @update_event_sql),
         :ok <- Sqlite3.bind(statement, [event_cbor, seq]),
         :done <- Sqlite3.step(conn, statement),
         :ok <- Sqlite3.release(conn, statement) do
      :ok
    end
  end

  defp build_payload(seq, did, event_type, action, payload, rev, commit_cid, created_at) do
    %{
      "$type" => "com.atproto.sync.subscribeRepos" <> event_type,
      "seq" => seq,
      "did" => did,
      "action" => action,
      "time" => created_at
    }
    |> maybe_put("rev", rev)
    |> maybe_put("commit", commit_cid)
    |> Map.merge(payload)
  end

  defp event_from_row([seq, did, event_type, rev, commit_cid, event_cbor, created_at]) do
    %Event{
      seq: seq,
      did: did,
      event_type: event_type,
      rev: rev,
      commit_cid: commit_cid,
      payload: Drisl.decode!(event_cbor),
      event_cbor: event_cbor,
      created_at: created_at
    }
  end

  defp normalize_payload(payload) do
    Map.new(payload, fn {key, value} -> {to_string(key), normalize_value(value)} end)
  end

  defp normalize_value(%Drisl.Bytes{} = value), do: value
  defp normalize_value(value) when is_map(value), do: normalize_payload(value)
  defp normalize_value(value) when is_list(value), do: Enum.map(value, &normalize_value/1)
  defp normalize_value(value), do: value

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
