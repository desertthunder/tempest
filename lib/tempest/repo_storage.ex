defmodule Tempest.RepoStorage do
  @moduledoc """
  SQLite storage boundary for one hosted account repository.
  """

  alias Exqlite.Sqlite3
  alias Tempest.Accounts.Account
  alias Tempest.Config
  alias Tempest.Identity.KeyStore
  alias Tempest.Identity.SigningKey
  alias Tempest.RepoCore.{Cid, Commit, Did, Drisl, Mst, Tid}
  alias Tempest.RepoCore.Tid.Clock
  alias Tempest.Storage.Timestamp

  @sqlite_bootstrap """
  PRAGMA journal_mode = WAL;
  PRAGMA busy_timeout = 5000;
  PRAGMA foreign_keys = ON;
  """

  @repo_schema """
  CREATE TABLE IF NOT EXISTS blocks (
    cid TEXT PRIMARY KEY,
    codec TEXT NOT NULL CHECK (codec IN ('drisl', 'raw')),
    bytes BLOB NOT NULL,
    inserted_at TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS records (
    collection TEXT NOT NULL,
    rkey TEXT NOT NULL,
    path TEXT NOT NULL,
    cid TEXT NOT NULL,
    record_json TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    PRIMARY KEY (collection, rkey),
    UNIQUE (path),
    FOREIGN KEY (cid) REFERENCES blocks(cid)
  );

  CREATE INDEX IF NOT EXISTS records_collection_rkey_idx ON records (collection, rkey);
  CREATE INDEX IF NOT EXISTS records_collection_path_idx ON records (collection, path);

  CREATE TABLE IF NOT EXISTS commits (
    cid TEXT PRIMARY KEY,
    rev TEXT NOT NULL UNIQUE,
    prev_cid TEXT,
    data_cid TEXT NOT NULL,
    commit_bytes BLOB NOT NULL,
    inserted_at TEXT NOT NULL,
    FOREIGN KEY (cid) REFERENCES blocks(cid),
    FOREIGN KEY (data_cid) REFERENCES blocks(cid)
  );

  CREATE INDEX IF NOT EXISTS commits_rev_idx ON commits (rev);

  CREATE TABLE IF NOT EXISTS repo_metadata (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TEXT NOT NULL
  );
  """

  @doc """
  Creates the per-DID SQLite database and repo tables when absent.
  """
  def create_repo_database!(%Config{} = config, did) when is_binary(did) do
    path = repo_db_path!(config, did)
    File.mkdir_p!(Path.dirname(path))

    with {:ok, conn} <- Sqlite3.open(path),
         :ok <- Sqlite3.execute(conn, @sqlite_bootstrap <> @repo_schema),
         :ok <- Sqlite3.close(conn) do
      path
    else
      {:error, reason} ->
        raise RuntimeError, "failed to bootstrap repo database #{path}: #{inspect(reason)}"
    end
  end

  @doc """
  Initializes an empty signed v3 repo for an account.
  """
  def initialize_empty_repo(%Account{} = account, %SigningKey{} = signing_key, %Config{} = config \\ Config.load!()) do
    with {:ok, private_key} <- KeyStore.decrypt_private_key(signing_key),
         {:ok, repo} <- build_empty_repo(account.did, private_key),
         {:ok, conn, path} <- open_repo(config, account.did) do
      transact(conn, fn ->
        with :ok <- ensure_uninitialized(conn),
             :ok <- insert_blocks(conn, repo.blocks, repo.inserted_at),
             :ok <- insert_commit(conn, repo),
             :ok <- insert_metadata(conn, repo) do
          :ok
        end
      end)
      |> close_and_return(conn, path)
    end
  end

  @doc """
  Creates a record and advances the repository head commit.
  """
  def create_record(%Account{} = account, %SigningKey{} = signing_key, attrs, %Config{} = config \\ Config.load!())
      when is_map(attrs) do
    with {:ok, private_key} <- KeyStore.decrypt_private_key(signing_key),
         {:ok, record_bytes} <- Drisl.encode(attrs.record),
         record_cid = Cid.for_drisl(record_bytes),
         {:ok, conn, _path} <- open_repo(config, account.did) do
      transact(conn, fn ->
        with {:ok, current} <- current_repo(conn),
             :ok <- ensure_swap_commit(current, attrs.swap_commit),
             :ok <- ensure_record_absent(conn, attrs.collection, attrs.rkey),
             {:ok, repo} <- build_record_repo(account.did, private_key, current, attrs, record_cid, record_bytes),
             :ok <- insert_blocks(conn, repo.blocks, repo.inserted_at),
             :ok <- insert_record(conn, repo),
             :ok <- insert_commit(conn, repo),
             :ok <- update_metadata(conn, repo) do
          {:ok,
           %{
             uri: repo.uri,
             record_cid: repo.record_cid,
             commit_cid: repo.commit_cid,
             rev: repo.rev
           }}
        end
      end)
      |> close_and_return(conn)
    end
  end

  @doc """
  Creates or replaces a record and advances the repository head commit.
  """
  def put_record(%Account{} = account, %SigningKey{} = signing_key, attrs, %Config{} = config \\ Config.load!())
      when is_map(attrs) do
    with {:ok, private_key} <- KeyStore.decrypt_private_key(signing_key),
         {:ok, record_bytes} <- Drisl.encode(attrs.record),
         record_cid = Cid.for_drisl(record_bytes),
         {:ok, conn, _path} <- open_repo(config, account.did) do
      transact(conn, fn ->
        with {:ok, current} <- current_repo(conn),
             :ok <- ensure_swap_commit(current, attrs.swap_commit),
             {:ok, existing_record} <- current_record(conn, attrs.collection, attrs.rkey),
             :ok <- ensure_swap_record(existing_record, attrs.swap_record),
             {:ok, repo} <- build_put_record_repo(account.did, private_key, current, attrs, record_cid, record_bytes),
             :ok <- insert_blocks(conn, repo.blocks, repo.inserted_at),
             :ok <- upsert_record(conn, repo),
             :ok <- insert_commit(conn, repo),
             :ok <- update_metadata(conn, repo) do
          {:ok,
           %{
             uri: repo.uri,
             record_cid: repo.record_cid,
             commit_cid: repo.commit_cid,
             rev: repo.rev
           }}
        end
      end)
      |> close_and_return(conn)
    end
  end

  @doc """
  Deletes a current record, when present, and advances the repository head commit.
  """
  def delete_record(%Account{} = account, %SigningKey{} = signing_key, attrs, %Config{} = config \\ Config.load!())
      when is_map(attrs) do
    with {:ok, private_key} <- KeyStore.decrypt_private_key(signing_key),
         {:ok, conn, _path} <- open_repo(config, account.did) do
      transact(conn, fn ->
        with {:ok, current} <- current_repo(conn),
             {:ok, existing_record} <- current_record(conn, attrs.collection, attrs.rkey) do
          case existing_record do
            nil ->
              {:ok,
               %{
                 uri: "at://" <> account.did <> "/" <> attrs.collection <> "/" <> attrs.rkey,
                 deleted?: false
               }}

            _record ->
              with :ok <- ensure_swap_commit(current, attrs.swap_commit),
                   :ok <- ensure_swap_record(existing_record, attrs.swap_record),
                   {:ok, repo} <- build_delete_record_repo(account.did, private_key, current, attrs),
                   :ok <- insert_blocks(conn, repo.blocks, repo.inserted_at),
                   :ok <- delete_record_row(conn, repo.collection, repo.rkey),
                   :ok <- insert_commit(conn, repo),
                   :ok <- update_metadata(conn, repo) do
                {:ok,
                 %{
                   uri: repo.uri,
                   commit_cid: repo.commit_cid,
                   rev: repo.rev,
                   deleted?: true
                 }}
              end
          end
        end
      end)
      |> close_and_return(conn)
    end
  end

  @doc """
  Fetches the current record by collection and record key.
  """
  def get_record(did, collection, rkey, opts \\ [])
      when is_binary(did) and is_binary(collection) and is_binary(rkey) do
    requested_cid = Keyword.get(opts, :cid)
    config = Config.load!()

    with {:ok, conn, _path} <- open_repo(config, did) do
      result =
        with {:ok, record} <- current_record(conn, collection, rkey),
             {:ok, record} <- ensure_requested_cid(record, requested_cid) do
          {:ok, Map.put(record, :uri, "at://" <> did <> "/" <> collection <> "/" <> rkey)}
        end

      close_and_return(result, conn)
    end
  end

  @doc """
  Lists current records in one collection.
  """
  def list_records(did, collection, opts \\ [])
      when is_binary(did) and is_binary(collection) do
    limit = Keyword.fetch!(opts, :limit)
    cursor = Keyword.get(opts, :cursor)
    reverse? = Keyword.get(opts, :reverse?, false)
    config = Config.load!()

    with {:ok, conn, _path} <- open_repo(config, did) do
      result = records_page(conn, did, collection, limit, cursor, reverse?)
      close_and_return(result, conn)
    end
  end

  @doc """
  Returns collections that currently contain at least one record.
  """
  def list_collections(did, %Config{} = config \\ Config.load!()) when is_binary(did) do
    with {:ok, conn, _path} <- open_repo(config, did) do
      result =
        with {:ok, rows} <- fetch_all(conn, "SELECT DISTINCT collection FROM records ORDER BY collection", []) do
          {:ok, Enum.map(rows, fn [collection] -> collection end)}
        end

      close_and_return(result, conn)
    end
  end

  def repo_db_path!(%Config{} = config, did) when is_binary(did) do
    with {:ok, did} <- Did.parse(did) do
      Config.repo_db_path(config, did)
    else
      {:error, reason} -> raise ArgumentError, "invalid DID for repo database path: #{inspect(reason)}"
    end
  end

  defp open_repo(%Config{} = config, did) do
    path = create_repo_database!(config, did)

    case Sqlite3.open(path) do
      {:ok, conn} -> {:ok, conn, path}
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_empty_repo(did, private_key) do
    rev = Tid.new!(Tid.now_unix_microseconds(), Clock.random_clock_id())

    with {:ok, %{root: root, blocks: mst_blocks}} <- Mst.serialize(Mst.new()),
         {:ok, unsigned_commit} <- Commit.new(did: did, data: root, rev: rev, prev: nil),
         {:ok, commit} <- Commit.sign(unsigned_commit, private_key),
         {:ok, commit_bytes} <- Commit.encode(commit),
         {:ok, commit_cid} <- Commit.cid(commit) do
      inserted_at = Timestamp.iso8601_utc()

      {:ok,
       %{
         did: did,
         rev: rev.value,
         root_cid: Cid.to_string(root),
         commit_cid: Cid.to_string(commit_cid),
         commit_bytes: commit_bytes,
         inserted_at: inserted_at,
         blocks: mst_blocks ++ [{commit_cid, commit_bytes}]
       }}
    end
  end

  defp transact(conn, fun) do
    with :ok <- Sqlite3.execute(conn, "BEGIN IMMEDIATE;") do
      case fun.() do
        :ok ->
          Sqlite3.execute(conn, "COMMIT;")

        {:ok, value} ->
          with :ok <- Sqlite3.execute(conn, "COMMIT;") do
            {:ok, value}
          end

        {:error, reason} ->
          _ = Sqlite3.execute(conn, "ROLLBACK;")
          {:error, reason}
      end
    end
  end

  defp close_and_return(result, conn, path) do
    close_result = Sqlite3.close(conn)

    case {result, close_result} do
      {:ok, :ok} -> {:ok, path}
      {{:ok, value}, :ok} -> {:ok, value}
      {{:error, reason}, :ok} -> {:error, reason}
      {:ok, {:error, reason}} -> {:error, reason}
      {{:error, reason}, {:error, _close_reason}} -> {:error, reason}
    end
  end

  defp close_and_return(result, conn) do
    close_result = Sqlite3.close(conn)

    case {result, close_result} do
      {{:ok, value}, :ok} -> {:ok, value}
      {:ok, :ok} -> :ok
      {{:error, reason}, :ok} -> {:error, reason}
      {{:ok, _value}, {:error, reason}} -> {:error, reason}
      {:ok, {:error, reason}} -> {:error, reason}
      {{:error, reason}, {:error, _close_reason}} -> {:error, reason}
    end
  end

  defp ensure_uninitialized(conn) do
    case fetch_value(conn, "SELECT value FROM repo_metadata WHERE key = 'did'") do
      {:ok, nil} -> :ok
      {:ok, _did} -> {:error, :repo_already_initialized}
      {:error, reason} -> {:error, reason}
    end
  end

  defp insert_blocks(conn, blocks, inserted_at) do
    Enum.reduce_while(blocks, :ok, fn {cid, bytes}, :ok ->
      cid_value = Cid.to_string(cid)
      codec = Atom.to_string(cid.codec)

      case execute(conn, "INSERT OR IGNORE INTO blocks (cid, codec, bytes, inserted_at) VALUES (?1, ?2, ?3, ?4)", [
             cid_value,
             codec,
             bytes,
             inserted_at
           ]) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp current_repo(conn) do
    with {:ok, metadata} <- repo_metadata(conn),
         {:ok, entries} <- current_record_entries(conn),
         {:ok, prev_cid} <- parse_cid(Map.get(metadata, "current_commit_cid")) do
      {:ok,
       %{
         rev: Map.fetch!(metadata, "current_rev"),
         commit_cid: Map.fetch!(metadata, "current_commit_cid"),
         root_cid: Map.fetch!(metadata, "current_root_cid"),
         prev_cid: prev_cid,
         entries: entries
       }}
    end
  end

  defp repo_metadata(conn) do
    with {:ok, rows} <- fetch_all(conn, "SELECT key, value FROM repo_metadata", []) do
      {:ok, Map.new(rows, fn [key, value] -> {key, value} end)}
    end
  end

  defp current_record_entries(conn) do
    with {:ok, rows} <- fetch_all(conn, "SELECT path, cid FROM records ORDER BY path", []) do
      Enum.reduce_while(rows, {:ok, []}, fn [path, cid], {:ok, entries} ->
        case Cid.parse(cid) do
          {:ok, cid} -> {:cont, {:ok, [{path, cid} | entries]}}
          {:error, reason} -> {:halt, {:error, {:invalid_record_cid, reason}}}
        end
      end)
    end
  end

  defp ensure_swap_commit(_current, nil), do: :ok
  defp ensure_swap_commit(%{commit_cid: current_commit_cid}, current_commit_cid), do: :ok
  defp ensure_swap_commit(_current, _swap_commit), do: {:error, :invalid_swap}

  defp ensure_swap_record(_existing_record, nil), do: :ok
  defp ensure_swap_record(%{cid: current_cid}, current_cid), do: :ok
  defp ensure_swap_record(_existing_record, _swap_record), do: {:error, :invalid_swap}

  defp ensure_record_absent(conn, collection, rkey) do
    with {:ok, [[count]]} <-
           fetch_all(conn, "SELECT COUNT(*) FROM records WHERE collection = ?1 AND rkey = ?2", [collection, rkey]) do
      if count == 0 do
        :ok
      else
        {:error, :duplicate_record}
      end
    end
  end

  defp build_record_repo(did, private_key, current, attrs, record_cid, record_bytes) do
    path = attrs.collection <> "/" <> attrs.rkey
    entries = Enum.reverse(current.entries) ++ [{path, record_cid}]

    build_record_commit(did, private_key, current, attrs, path, entries, record_cid, record_bytes)
  end

  defp build_put_record_repo(did, private_key, current, attrs, record_cid, record_bytes) do
    path = attrs.collection <> "/" <> attrs.rkey

    entries =
      current.entries
      |> Enum.reverse()
      |> Enum.reject(fn {entry_path, _cid} -> entry_path == path end)
      |> Kernel.++([{path, record_cid}])

    build_record_commit(did, private_key, current, attrs, path, entries, record_cid, record_bytes)
  end

  defp build_delete_record_repo(did, private_key, current, attrs) do
    path = attrs.collection <> "/" <> attrs.rkey

    entries =
      current.entries
      |> Enum.reverse()
      |> Enum.reject(fn {entry_path, _cid} -> entry_path == path end)

    with {:ok, mst} <- Mst.from_entries(entries),
         {:ok, %{root: root, blocks: mst_blocks}} <- Mst.serialize(mst),
         {:ok, commit} <- signed_commit(did, private_key, root, current.prev_cid, current.rev),
         {:ok, commit_bytes} <- Commit.encode(commit),
         {:ok, commit_cid} <- Commit.cid(commit) do
      inserted_at = Timestamp.iso8601_utc()
      commit_cid_string = Cid.to_string(commit_cid)
      root_cid_string = Cid.to_string(root)

      {:ok,
       %{
         collection: attrs.collection,
         rkey: attrs.rkey,
         path: path,
         uri: "at://" <> did <> "/" <> path,
         rev: commit.rev,
         prev_cid: current.commit_cid,
         root_cid: root_cid_string,
         commit_cid: commit_cid_string,
         commit_bytes: commit_bytes,
         inserted_at: inserted_at,
         blocks: mst_blocks ++ [{commit_cid, commit_bytes}]
       }}
    end
  end

  defp build_record_commit(did, private_key, current, attrs, path, entries, record_cid, record_bytes) do
    with {:ok, mst} <- Mst.from_entries(entries),
         {:ok, %{root: root, blocks: mst_blocks}} <- Mst.serialize(mst),
         {:ok, commit} <- signed_commit(did, private_key, root, current.prev_cid, current.rev),
         {:ok, commit_bytes} <- Commit.encode(commit),
         {:ok, commit_cid} <- Commit.cid(commit) do
      inserted_at = Timestamp.iso8601_utc()
      commit_cid_string = Cid.to_string(commit_cid)
      record_cid_string = Cid.to_string(record_cid)
      root_cid_string = Cid.to_string(root)

      {:ok,
       %{
         collection: attrs.collection,
         rkey: attrs.rkey,
         path: path,
         uri: "at://" <> did <> "/" <> path,
         record: attrs.record,
         record_cid: record_cid_string,
         rev: commit.rev,
         prev_cid: current.commit_cid,
         root_cid: root_cid_string,
         commit_cid: commit_cid_string,
         commit_bytes: commit_bytes,
         inserted_at: inserted_at,
         blocks: [{record_cid, record_bytes}] ++ mst_blocks ++ [{commit_cid, commit_bytes}]
       }}
    end
  end

  defp signed_commit(did, private_key, root, prev_cid, current_rev) do
    with {:ok, unsigned_commit} <- Commit.new(did: did, data: root, rev: next_rev(current_rev), prev: prev_cid) do
      Commit.sign(unsigned_commit, private_key)
    end
  end

  defp next_rev(current_rev) do
    current = Tid.parse!(current_rev)
    proposed = Tid.new!(Tid.now_unix_microseconds(), Clock.random_clock_id())

    if proposed.integer > current.integer do
      proposed.value
    else
      current.integer
      |> Kernel.+(1)
      |> Tid.from_integer!()
      |> Map.fetch!(:value)
    end
  end

  defp insert_record(conn, repo) do
    execute(
      conn,
      """
      INSERT INTO records (collection, rkey, path, cid, record_json, created_at, updated_at)
      VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?6)
      """,
      [
        repo.collection,
        repo.rkey,
        repo.path,
        repo.record_cid,
        Jason.encode!(repo.record),
        repo.inserted_at
      ]
    )
  end

  defp upsert_record(conn, repo) do
    execute(
      conn,
      """
      INSERT INTO records (collection, rkey, path, cid, record_json, created_at, updated_at)
      VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?6)
      ON CONFLICT(collection, rkey) DO UPDATE SET
        path = excluded.path,
        cid = excluded.cid,
        record_json = excluded.record_json,
        updated_at = excluded.updated_at
      """,
      [
        repo.collection,
        repo.rkey,
        repo.path,
        repo.record_cid,
        Jason.encode!(repo.record),
        repo.inserted_at
      ]
    )
  end

  defp delete_record_row(conn, collection, rkey) do
    execute(conn, "DELETE FROM records WHERE collection = ?1 AND rkey = ?2", [collection, rkey])
  end

  defp current_record(conn, collection, rkey) do
    with {:ok, rows} <-
           fetch_all(
             conn,
             """
             SELECT collection, rkey, path, cid, record_json
             FROM records
             WHERE collection = ?1 AND rkey = ?2
             """,
             [collection, rkey]
           ) do
      case rows do
        [] -> {:ok, nil}
        [[collection, rkey, path, cid, record_json]] -> decode_record(collection, rkey, path, cid, record_json)
      end
    end
  end

  defp ensure_requested_cid(nil, _requested_cid), do: {:error, :record_not_found}
  defp ensure_requested_cid(record, nil), do: {:ok, record}
  defp ensure_requested_cid(%{cid: requested_cid} = record, requested_cid), do: {:ok, record}
  defp ensure_requested_cid(_record, _requested_cid), do: {:error, :record_not_found}

  defp records_page(conn, did, collection, limit, nil, false) do
    records_page_query(
      conn,
      did,
      collection,
      "SELECT collection, rkey, path, cid, record_json FROM records WHERE collection = ?1 ORDER BY rkey ASC LIMIT ?2",
      [collection, limit + 1],
      limit
    )
  end

  defp records_page(conn, did, collection, limit, cursor, false) do
    records_page_query(
      conn,
      did,
      collection,
      """
      SELECT collection, rkey, path, cid, record_json
      FROM records
      WHERE collection = ?1 AND rkey > ?2
      ORDER BY rkey ASC
      LIMIT ?3
      """,
      [collection, cursor, limit + 1],
      limit
    )
  end

  defp records_page(conn, did, collection, limit, nil, true) do
    records_page_query(
      conn,
      did,
      collection,
      "SELECT collection, rkey, path, cid, record_json FROM records WHERE collection = ?1 ORDER BY rkey DESC LIMIT ?2",
      [collection, limit + 1],
      limit
    )
  end

  defp records_page(conn, did, collection, limit, cursor, true) do
    records_page_query(
      conn,
      did,
      collection,
      """
      SELECT collection, rkey, path, cid, record_json
      FROM records
      WHERE collection = ?1 AND rkey < ?2
      ORDER BY rkey DESC
      LIMIT ?3
      """,
      [collection, cursor, limit + 1],
      limit
    )
  end

  defp records_page_query(conn, did, collection, sql, params, limit) do
    with {:ok, rows} <- fetch_all(conn, sql, params),
         {:ok, records} <- decode_records(rows) do
      page_records = Enum.take(records, limit)

      response = %{
        records:
          Enum.map(page_records, fn record ->
            %{
              uri: "at://" <> did <> "/" <> collection <> "/" <> record.rkey,
              cid: record.cid,
              value: record.value
            }
          end)
      }

      response =
        if length(records) > limit do
          Map.put(response, :cursor, List.last(page_records).rkey)
        else
          response
        end

      {:ok, response}
    end
  end

  defp decode_records(rows) do
    Enum.reduce_while(rows, {:ok, []}, fn [collection, rkey, path, cid, record_json], {:ok, records} ->
      case decode_record(collection, rkey, path, cid, record_json) do
        {:ok, record} -> {:cont, {:ok, [record | records]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, records} -> {:ok, Enum.reverse(records)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp decode_record(collection, rkey, path, cid, record_json) do
    case Jason.decode(record_json) do
      {:ok, value} ->
        {:ok, %{collection: collection, rkey: rkey, path: path, uri: nil, cid: cid, value: value}}

      {:error, reason} ->
        {:error, {:invalid_record_json, reason}}
    end
  end

  defp insert_commit(conn, repo) do
    execute(
      conn,
      """
      INSERT INTO commits (cid, rev, prev_cid, data_cid, commit_bytes, inserted_at)
      VALUES (?1, ?2, ?3, ?4, ?5, ?6)
      """,
      [
        repo.commit_cid,
        repo.rev,
        Map.get(repo, :prev_cid),
        repo.root_cid,
        repo.commit_bytes,
        repo.inserted_at
      ]
    )
  end

  defp insert_metadata(conn, repo) do
    metadata = %{
      "did" => repo.did,
      "version" => "3",
      "current_rev" => repo.rev,
      "current_commit_cid" => repo.commit_cid,
      "current_root_cid" => repo.root_cid,
      "initialized_at" => repo.inserted_at
    }

    Enum.reduce_while(metadata, :ok, fn {key, value}, :ok ->
      case execute(conn, "INSERT INTO repo_metadata (key, value, updated_at) VALUES (?1, ?2, ?3)", [
             key,
             value,
             repo.inserted_at
           ]) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp update_metadata(conn, repo) do
    metadata = %{
      "current_rev" => repo.rev,
      "current_commit_cid" => repo.commit_cid,
      "current_root_cid" => repo.root_cid
    }

    Enum.reduce_while(metadata, :ok, fn {key, value}, :ok ->
      case execute(conn, "UPDATE repo_metadata SET value = ?1, updated_at = ?2 WHERE key = ?3", [
             value,
             repo.inserted_at,
             key
           ]) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp execute(conn, sql, params) do
    with {:ok, statement} <- Sqlite3.prepare(conn, sql),
         :ok <- Sqlite3.bind(statement, params),
         :done <- Sqlite3.step(conn, statement),
         :ok <- Sqlite3.release(conn, statement) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_value(conn, sql) do
    with {:ok, statement} <- Sqlite3.prepare(conn, sql),
         {:ok, rows} <- Sqlite3.fetch_all(conn, statement),
         :ok <- Sqlite3.release(conn, statement) do
      case rows do
        [] -> {:ok, nil}
        [[value]] -> {:ok, value}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_all(conn, sql, params) do
    with {:ok, statement} <- Sqlite3.prepare(conn, sql),
         :ok <- Sqlite3.bind(statement, params),
         {:ok, rows} <- Sqlite3.fetch_all(conn, statement),
         :ok <- Sqlite3.release(conn, statement) do
      {:ok, rows}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_cid(nil), do: {:error, :missing_commit_cid}

  defp parse_cid(cid) do
    case Cid.parse(cid) do
      {:ok, cid} -> {:ok, cid}
      {:error, reason} -> {:error, {:invalid_commit_cid, reason}}
    end
  end
end
