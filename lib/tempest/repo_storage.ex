defmodule Tempest.RepoStorage do
  @moduledoc """
  SQLite storage boundary for one hosted account repository.
  """

  alias Exqlite.Sqlite3
  alias Tempest.Accounts.Account
  alias Tempest.Config
  alias Tempest.Identity.KeyStore
  alias Tempest.Identity.SigningKey
  alias Tempest.RepoCore.{Car, Cid, Commit, Did, Drisl, Mst, Tid}
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
  Atomically replaces a repository with a verified import CAR.
  """
  def import_verified_car(%Account{} = account, verified, %Config{} = config \\ Config.load!()) when is_map(verified) do
    with {:ok, conn, _path} <- open_repo(config, account.did) do
      result =
        transact(conn, fn ->
          with :ok <- clear_repo(conn),
               {:ok, imported} <- imported_repo(account.did, verified),
               :ok <- insert_blocks(conn, imported.blocks, imported.inserted_at),
               :ok <- insert_imported_records(conn, imported.records, imported.inserted_at),
               :ok <- insert_commit(conn, imported),
               :ok <- insert_metadata(conn, imported) do
            {:ok,
             %{
               cid: imported.commit_cid,
               rev: imported.rev,
               record_count: length(imported.records)
             }}
          end
        end)

      close_and_return(result, conn)
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
             rev: repo.rev,
             prev_rev: current.rev,
             prev_data: current.root_cid
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
             rev: repo.rev,
             prev_rev: current.rev,
             prev_data: current.root_cid,
             prev_record_cid: existing_record && existing_record.cid
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
                   prev_rev: current.rev,
                   prev_data: current.root_cid,
                   prev_record_cid: existing_record.cid,
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
  Applies a batch of record writes atomically and advances the repository head once.
  """
  def apply_writes(%Account{} = account, %SigningKey{} = signing_key, attrs, %Config{} = config \\ Config.load!())
      when is_map(attrs) do
    with {:ok, private_key} <- KeyStore.decrypt_private_key(signing_key),
         {:ok, conn, _path} <- open_repo(config, account.did) do
      transact(conn, fn ->
        with {:ok, current} <- current_repo(conn),
             :ok <- ensure_swap_commit(current, attrs.swap_commit),
             {:ok, repo} <- build_apply_writes_repo(conn, account.did, private_key, current, attrs.writes),
             :ok <- insert_blocks(conn, repo.blocks, repo.inserted_at),
             :ok <- apply_write_rows(conn, repo),
             :ok <- insert_commit(conn, repo),
             :ok <- update_metadata(conn, repo) do
          {:ok,
           %{
             commit_cid: repo.commit_cid,
             rev: repo.rev,
             prev_rev: current.rev,
             prev_data: current.root_cid,
             results: repo.results,
             paths: repo.paths,
             ops: repo.ops
           }}
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

  @doc """
  Lists recent current records for operator/account inspection.
  """
  def list_recent_records(did, opts \\ [], %Config{} = config \\ Config.load!())
      when is_binary(did) and is_list(opts) do
    limit = Keyword.get(opts, :limit, 50)

    with {:ok, conn, _path} <- open_repo(config, did) do
      result =
        with {:ok, rows} <-
               fetch_all(
                 conn,
                 """
                 SELECT collection, rkey, path, cid, record_json, created_at, updated_at
                 FROM records
                 ORDER BY updated_at DESC, path ASC
                 LIMIT ?1
                 """,
                 [limit]
               ) do
          Enum.reduce_while(rows, {:ok, []}, fn [collection, rkey, path, cid, record_json, created_at, updated_at],
                                                {:ok, records} ->
            case Jason.decode(record_json) do
              {:ok, value} ->
                record = %{
                  collection: collection,
                  rkey: rkey,
                  path: path,
                  cid: cid,
                  value: value,
                  created_at: created_at,
                  updated_at: updated_at
                }

                {:cont, {:ok, [record | records]}}

              {:error, reason} ->
                {:halt, {:error, {:invalid_record_json, reason}}}
            end
          end)
          |> case do
            {:ok, records} -> {:ok, Enum.reverse(records)}
            {:error, reason} -> {:error, reason}
          end
        end

      close_and_return(result, conn)
    end
  end

  @doc """
  Exports the repository as a CAR v1 archive rooted at the current commit.
  """
  def export_car(did, %Config{} = config \\ Config.load!()) when is_binary(did) do
    with {:ok, conn, _path} <- open_repo(config, did) do
      result =
        with {:ok, metadata} <- repo_metadata(conn),
             {:ok, root_cid} <- parse_cid(Map.get(metadata, "current_commit_cid")),
             {:ok, blocks} <- car_blocks(conn),
             {:ok, bytes} <- Car.encode([root_cid], blocks) do
          {:ok, %{root: Cid.to_string(root_cid), bytes: bytes}}
        end

      close_and_return(result, conn)
    end
  end

  @doc """
  Returns the current commit CID and revision for the repository.
  """
  def latest_commit(did, %Config{} = config \\ Config.load!()) when is_binary(did) do
    with {:ok, conn, _path} <- open_repo(config, did) do
      result =
        with {:ok, metadata} <- repo_metadata(conn),
             {:ok, cid} <- fetch_metadata(metadata, "current_commit_cid"),
             {:ok, rev} <- fetch_metadata(metadata, "current_rev") do
          {:ok, %{cid: cid, rev: rev}}
        end

      close_and_return(result, conn)
    end
  end

  @doc """
  Exports a CAR containing exactly the requested blocks.
  """
  def export_blocks_car(did, cids, %Config{} = config \\ Config.load!()) when is_binary(did) and is_list(cids) do
    with {:ok, conn, _path} <- open_repo(config, did) do
      result =
        with {:ok, parsed_cids} <- parse_cids(cids),
             {:ok, blocks} <- selected_blocks(conn, parsed_cids),
             {:ok, bytes} <- Car.encode(parsed_cids, blocks) do
          {:ok, %{roots: Enum.map(parsed_cids, &Cid.to_string/1), bytes: bytes}}
        end

      close_and_return(result, conn)
    end
  end

  @doc """
  Returns repository, record, and referenced-blob counts for status checks.
  """
  def status_counts(did, %Config{} = config \\ Config.load!()) when is_binary(did) do
    with {:ok, conn, _path} <- open_repo(config, did) do
      result =
        with {:ok, records} <- scalar_count(conn, "SELECT COUNT(*) FROM records", []),
             {:ok, commits} <- scalar_count(conn, "SELECT COUNT(*) FROM commits", []),
             {:ok, collections} <- scalar_count(conn, "SELECT COUNT(DISTINCT collection) FROM records", []),
             {:ok, blocks} <- scalar_count(conn, "SELECT COUNT(*) FROM blocks", []),
             {:ok, referenced_cids} <- referenced_blob_cids_from_db(conn),
             {:ok, latest_record_at} <- scalar_value(conn, "SELECT MAX(updated_at) FROM records", []),
             {:ok, latest_commit_at} <- scalar_value(conn, "SELECT MAX(inserted_at) FROM commits", []) do
          {:ok,
           %{
             repo_count: if(commits > 0, do: 1, else: 0),
             block_count: blocks,
             commit_count: commits,
             collection_count: collections,
             record_count: records,
             latest_record_at: latest_record_at,
             latest_commit_at: latest_commit_at,
             latest_activity_at: max_iso8601([latest_record_at, latest_commit_at]),
             referenced_blob_count: length(referenced_cids),
             referenced_blob_cids: referenced_cids
           }}
        end

      close_and_return(result, conn)
    end
  end

  @doc """
  Lists blob CIDs referenced by current records.
  """
  def list_referenced_blobs(did, opts \\ []) when is_binary(did) do
    limit = Keyword.fetch!(opts, :limit)
    cursor = Keyword.get(opts, :cursor)
    config = Config.load!()

    with {:ok, conn, _path} <- open_repo(config, did) do
      result =
        with {:ok, rows} <- fetch_all(conn, "SELECT record_json FROM records ORDER BY path ASC", []) do
          cids =
            rows
            |> Enum.flat_map(fn [record_json] -> referenced_blob_cids(record_json) end)
            |> Enum.uniq()
            |> Enum.sort()

          page_after_cursor(cids, limit, cursor, :cids)
        end

      close_and_return(result, conn)
    end
  end

  @doc """
  Exports the blocks needed to read a record at the selected commit.
  """
  def export_record_car(did, collection, rkey, opts \\ [])
      when is_binary(did) and is_binary(collection) and is_binary(rkey) do
    commit = Keyword.get(opts, :commit)
    config = Config.load!()

    with {:ok, conn, _path} <- open_repo(config, did) do
      path = collection <> "/" <> rkey

      result =
        with {:ok, commit_row} <- commit_row(conn, commit),
             {:ok, commit_cid} <- parse_cid(commit_row.cid),
             {:ok, commit} <- decode_commit(commit_row.commit_bytes, commit_cid),
             {:ok, proof} <- mst_record_proof(conn, commit.data, path),
             {:ok, record_bytes} <- block_bytes(conn, proof.record_cid),
             {:ok, bytes} <-
               Car.encode([commit_cid], [
                 {commit_cid, commit_row.commit_bytes}
                 | proof.mst_blocks ++ [{proof.record_cid, record_bytes}]
               ]) do
          {:ok, %{root: Cid.to_string(commit_cid), record: Cid.to_string(proof.record_cid), bytes: bytes}}
        end

      close_and_return(result, conn)
    end
  end

  @doc """
  Exports a firehose CAR slice rooted at a specific commit.

  The slice contains the commit block, the MST blocks reachable from that
  commit, and any current record blocks for the requested paths.
  """
  def export_commit_car_slice(did, commit_cid, opts \\ [])
      when is_binary(did) and is_binary(commit_cid) do
    paths = Keyword.get(opts, :paths, [])
    config = Config.load!()

    with {:ok, conn, _path} <- open_repo(config, did) do
      result =
        with {:ok, commit_row} <- commit_row(conn, commit_cid),
             {:ok, parsed_commit_cid} <- parse_cid(commit_row.cid),
             {:ok, commit} <- decode_commit(commit_row.commit_bytes, parsed_commit_cid),
             {:ok, proof} <- collect_mst(conn, commit.data, MapSet.new(), %{}),
             {:ok, record_blocks} <- record_blocks_for_paths(conn, proof.entries, paths),
             blocks <- unique_blocks([{parsed_commit_cid, commit_row.commit_bytes} | proof.blocks ++ record_blocks]),
             {:ok, bytes} <- Car.encode([parsed_commit_cid], blocks) do
          {:ok, %{root: Cid.to_string(parsed_commit_cid), bytes: bytes}}
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

  defp imported_repo(did, %{car: car, commit: commit, commit_cid: commit_cid, entries: entries}) do
    inserted_at = Timestamp.iso8601_utc()
    blocks = Enum.map(car.blocks, fn %{cid: cid, data: bytes} -> {cid, bytes} end)
    blocks_by_cid = Map.new(blocks, fn {cid, bytes} -> {Cid.to_string(cid), bytes} end)

    with {:ok, records} <- imported_records(entries, blocks_by_cid) do
      {:ok,
       %{
         did: did,
         rev: commit.rev,
         prev_cid: commit.prev && Cid.to_string(commit.prev),
         root_cid: Cid.to_string(commit.data),
         commit_cid: Cid.to_string(commit_cid),
         commit_bytes: Map.fetch!(blocks_by_cid, Cid.to_string(commit_cid)),
         inserted_at: inserted_at,
         blocks: blocks,
         records: records
       }}
    end
  end

  defp imported_records(entries, blocks_by_cid) do
    entries
    |> Enum.sort_by(fn {path, _cid} -> path end)
    |> Enum.reduce_while({:ok, []}, fn {path, cid}, {:ok, records} ->
      with {:ok, collection, rkey} <- split_repo_path(path),
           {:ok, record} <- imported_record(path, cid, collection, rkey, blocks_by_cid) do
        {:cont, {:ok, [record | records]}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, records} -> {:ok, Enum.reverse(records)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp split_repo_path(path) when is_binary(path) do
    case String.split(path, "/", parts: 2) do
      [collection, rkey] when collection != "" and rkey != "" -> {:ok, collection, rkey}
      _parts -> {:error, :invalid_import_path}
    end
  end

  defp split_repo_path(_path), do: {:error, :invalid_import_path}

  defp imported_record(path, cid, collection, rkey, blocks_by_cid) do
    cid_value = Cid.to_string(cid)

    with {:ok, bytes} <- Map.fetch(blocks_by_cid, cid_value),
         {:ok, record} <- Drisl.decode(bytes),
         {:ok, record} <- json_safe_record(record) do
      {:ok,
       %{
         collection: collection,
         rkey: rkey,
         path: path,
         record_cid: cid_value,
         record: record
       }}
    else
      :error -> {:error, {:missing_block, cid_value}}
      {:error, reason} -> {:error, {:invalid_import_record, reason}}
    end
  end

  defp json_safe_record(%Cid{} = cid), do: {:ok, %{"$link" => Cid.to_string(cid)}}

  defp json_safe_record(%Drisl.Bytes{bytes: bytes}) do
    {:ok, Base.url_encode64(bytes, padding: false)}
  end

  defp json_safe_record(map) when is_map(map) do
    Enum.reduce_while(map, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
      with true <- is_binary(key),
           {:ok, value} <- json_safe_record(value) do
        {:cont, {:ok, Map.put(acc, key, value)}}
      else
        false -> {:halt, {:error, :invalid_import_record}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp json_safe_record(list) when is_list(list) do
    Enum.reduce_while(list, {:ok, []}, fn value, {:ok, acc} ->
      case json_safe_record(value) do
        {:ok, value} -> {:cont, {:ok, [value | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp json_safe_record(value) when is_binary(value) or is_integer(value) or is_boolean(value) or is_nil(value),
    do: {:ok, value}

  defp json_safe_record(_value), do: {:error, :invalid_import_record}

  defp clear_repo(conn) do
    [
      "DELETE FROM records",
      "DELETE FROM commits",
      "DELETE FROM repo_metadata",
      "DELETE FROM blocks"
    ]
    |> Enum.reduce_while(:ok, fn sql, :ok ->
      case execute(conn, sql, []) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp insert_imported_records(conn, records, inserted_at) do
    Enum.reduce_while(records, :ok, fn record, :ok ->
      case insert_record(conn, Map.put(record, :inserted_at, inserted_at)) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
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

  defp car_blocks(conn) do
    with {:ok, rows} <- fetch_all(conn, "SELECT cid, bytes FROM blocks ORDER BY inserted_at ASC, cid ASC", []) do
      Enum.reduce_while(rows, {:ok, []}, fn [cid, bytes], {:ok, blocks} ->
        case Cid.parse(cid) do
          {:ok, cid} -> {:cont, {:ok, [{cid, bytes} | blocks]}}
          {:error, reason} -> {:halt, {:error, {:invalid_block_cid, reason}}}
        end
      end)
      |> case do
        {:ok, blocks} -> {:ok, Enum.reverse(blocks)}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp parse_cids(cids) do
    Enum.reduce_while(cids, {:ok, []}, fn cid, {:ok, parsed} ->
      case Cid.parse(cid) do
        {:ok, cid} -> {:cont, {:ok, [cid | parsed]}}
        {:error, _reason} -> {:halt, {:error, :invalid_cid}}
      end
    end)
    |> case do
      {:ok, parsed} -> {:ok, Enum.reverse(parsed)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp selected_blocks(conn, cids) do
    Enum.reduce_while(cids, {:ok, []}, fn cid, {:ok, blocks} ->
      case block_bytes(conn, cid) do
        {:ok, bytes} -> {:cont, {:ok, [{cid, bytes} | blocks]}}
        {:error, :block_not_found} -> {:halt, {:error, :block_not_found}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, blocks} -> {:ok, Enum.reverse(blocks)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp referenced_blob_cids_from_db(conn) do
    with {:ok, rows} <- fetch_all(conn, "SELECT record_json FROM records", []) do
      cids =
        rows
        |> Enum.flat_map(fn [record_json] -> referenced_blob_cids(record_json) end)
        |> Enum.uniq()
        |> Enum.sort()

      {:ok, cids}
    end
  end

  defp scalar_count(conn, sql, params) do
    case fetch_all(conn, sql, params) do
      {:ok, [[count]]} when is_integer(count) -> {:ok, count}
      {:ok, _rows} -> {:error, :unexpected_count_result}
      {:error, reason} -> {:error, reason}
    end
  end

  defp scalar_value(conn, sql, params) do
    case fetch_all(conn, sql, params) do
      {:ok, [[value]]} -> {:ok, value}
      {:ok, _rows} -> {:error, :unexpected_scalar_result}
      {:error, reason} -> {:error, reason}
    end
  end

  defp max_iso8601(values) do
    values
    |> Enum.reject(&is_nil/1)
    |> Enum.max(fn -> nil end)
  end

  defp referenced_blob_cids(record_json) do
    case Jason.decode(record_json) do
      {:ok, record} -> collect_blob_cids(record, [])
      {:error, _reason} -> []
    end
  end

  defp collect_blob_cids(%{"$type" => "blob", "ref" => %{"$link" => cid}}, acc) when is_binary(cid) do
    if Cid.valid?(cid), do: [cid | acc], else: acc
  end

  defp collect_blob_cids(%{"cid" => cid, "mimeType" => _mime_type} = value, acc) when is_binary(cid) do
    if Map.has_key?(value, "$type") and Cid.valid?(cid), do: [cid | acc], else: collect_map_blob_cids(value, acc)
  end

  defp collect_blob_cids(map, acc) when is_map(map), do: collect_map_blob_cids(map, acc)

  defp collect_blob_cids(list, acc) when is_list(list) do
    Enum.reduce(list, acc, &collect_blob_cids/2)
  end

  defp collect_blob_cids(_value, acc), do: acc

  defp collect_map_blob_cids(map, acc) do
    map
    |> Map.values()
    |> Enum.reduce(acc, &collect_blob_cids/2)
  end

  defp page_after_cursor(values, limit, cursor, key) do
    page_values =
      values
      |> Enum.drop_while(fn value -> cursor && value <= cursor end)
      |> Enum.take(limit + 1)

    visible = Enum.take(page_values, limit)
    response = %{key => visible}

    if length(page_values) > limit do
      {:ok, Map.put(response, :cursor, List.last(visible))}
    else
      {:ok, response}
    end
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

  defp fetch_metadata(metadata, key) do
    case Map.fetch(metadata, key) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, {:missing_repo_metadata, key}}
    end
  end

  defp commit_row(conn, nil) do
    with {:ok, metadata} <- repo_metadata(conn),
         {:ok, cid} <- fetch_metadata(metadata, "current_commit_cid") do
      commit_row(conn, cid)
    end
  end

  defp commit_row(conn, commit_cid) when is_binary(commit_cid) do
    with {:ok, rows} <-
           fetch_all(conn, "SELECT cid, rev, data_cid, commit_bytes FROM commits WHERE cid = ?1", [commit_cid]) do
      case rows do
        [[cid, rev, data_cid, commit_bytes]] ->
          {:ok, %{cid: cid, rev: rev, data_cid: data_cid, commit_bytes: commit_bytes}}

        [] ->
          {:error, :commit_not_found}
      end
    end
  end

  defp decode_commit(commit_bytes, expected_cid) do
    with {:ok, commit} <- Commit.decode(commit_bytes),
         ^expected_cid <- Commit.cid!(commit) do
      {:ok, commit}
    else
      {:error, reason} -> {:error, {:invalid_commit, reason}}
      _mismatch -> {:error, :commit_cid_mismatch}
    end
  end

  defp mst_record_proof(conn, root_cid, path) do
    with {:ok, proof} <- collect_mst(conn, root_cid, MapSet.new(), %{}) do
      case Map.fetch(proof.entries, path) do
        {:ok, record_cid} ->
          {:ok, %{record_cid: record_cid, mst_blocks: Enum.reverse(proof.blocks)}}

        :error ->
          {:error, :record_not_found}
      end
    end
  end

  defp collect_mst(_conn, nil, visited, entries), do: {:ok, %{visited: visited, entries: entries, blocks: []}}

  defp collect_mst(conn, %Cid{} = cid, visited, entries) do
    cid_value = Cid.to_string(cid)

    if MapSet.member?(visited, cid_value) do
      {:error, :mst_cycle}
    else
      with {:ok, bytes} <- block_bytes(conn, cid),
           {:ok, node} <- decode_mst_node(bytes),
           visited = MapSet.put(visited, cid_value),
           {:ok, left_proof} <- collect_mst_child(conn, Map.fetch!(node, "l"), visited, entries),
           {:ok, entries_proof} <-
             collect_mst_entries(conn, Map.fetch!(node, "e"), left_proof.visited, left_proof.entries) do
        {:ok, %{entries_proof | blocks: [{cid, bytes} | left_proof.blocks ++ entries_proof.blocks]}}
      end
    end
  end

  defp collect_mst_child(conn, child, visited, entries) do
    case collect_mst(conn, child, visited, entries) do
      {:ok, proof} -> {:ok, proof}
      {:error, reason} -> {:error, reason}
    end
  end

  defp collect_mst_entries(conn, entries, visited, acc_entries) when is_list(entries) do
    Enum.reduce_while(entries, {:ok, %{visited: visited, entries: acc_entries, blocks: [], previous_key: ""}}, fn entry,
                                                                                                                  {:ok,
                                                                                                                   proof} ->
      with {:ok, key, value, tree} <- decode_mst_entry(entry, proof.previous_key),
           {:ok, child} <- collect_mst_child(conn, tree, proof.visited, Map.put(proof.entries, key, value)) do
        {:cont,
         {:ok,
          %{
            visited: child.visited,
            entries: child.entries,
            blocks: proof.blocks ++ child.blocks,
            previous_key: key
          }}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, proof} -> {:ok, Map.delete(proof, :previous_key)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp collect_mst_entries(_conn, _entries, _visited, _acc_entries), do: {:error, :invalid_mst_node}

  defp decode_mst_node(bytes) do
    case Drisl.decode(bytes) do
      {:ok, %{"l" => left, "e" => entries} = node} when is_list(entries) ->
        if cid_or_nil?(left), do: {:ok, node}, else: {:error, :invalid_mst_node}

      {:ok, _value} ->
        {:error, :invalid_mst_node}

      {:error, reason} ->
        {:error, {:invalid_mst_node, reason}}
    end
  end

  defp decode_mst_entry(
         %{"p" => prefix_length, "k" => %Drisl.Bytes{bytes: suffix}, "v" => %Cid{} = value, "t" => tree},
         previous_key
       )
       when is_integer(prefix_length) and prefix_length >= 0 do
    if cid_or_nil?(tree) and prefix_length <= byte_size(previous_key) do
      key = binary_part(previous_key, 0, prefix_length) <> suffix
      {:ok, key, value, tree}
    else
      {:error, :invalid_mst_entry}
    end
  end

  defp decode_mst_entry(_entry, _previous_key), do: {:error, :invalid_mst_entry}

  defp cid_or_nil?(nil), do: true
  defp cid_or_nil?(%Cid{}), do: true
  defp cid_or_nil?(_value), do: false

  defp block_bytes(conn, %Cid{} = cid) do
    cid_value = Cid.to_string(cid)

    with {:ok, rows} <- fetch_all(conn, "SELECT bytes FROM blocks WHERE cid = ?1", [cid_value]) do
      case rows do
        [[bytes]] -> {:ok, bytes}
        [] -> {:error, :block_not_found}
      end
    end
  end

  defp record_blocks_for_paths(conn, entries, paths) when is_list(paths) do
    paths
    |> Enum.uniq()
    |> Enum.reduce_while({:ok, []}, fn path, {:ok, blocks} ->
      case Map.fetch(entries, path) do
        {:ok, %Cid{} = cid} ->
          case block_bytes(conn, cid) do
            {:ok, bytes} -> {:cont, {:ok, [{cid, bytes} | blocks]}}
            {:error, reason} -> {:halt, {:error, reason}}
          end

        :error ->
          {:cont, {:ok, blocks}}
      end
    end)
    |> case do
      {:ok, blocks} -> {:ok, Enum.reverse(blocks)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp unique_blocks(blocks) do
    blocks
    |> Enum.reduce({MapSet.new(), []}, fn {cid, bytes}, {seen, unique} ->
      cid_value = Cid.to_string(cid)

      if MapSet.member?(seen, cid_value) do
        {seen, unique}
      else
        {MapSet.put(seen, cid_value), [{cid, bytes} | unique]}
      end
    end)
    |> elem(1)
    |> Enum.reverse()
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

  defp build_apply_writes_repo(conn, did, private_key, current, writes) do
    with {:ok, prepared} <- prepare_apply_writes(conn, did, current, writes),
         entries <- prepared.entries |> Map.to_list() |> Enum.sort_by(fn {path, _cid} -> path end),
         {:ok, mst} <- Mst.from_entries(entries),
         {:ok, %{root: root, blocks: mst_blocks}} <- Mst.serialize(mst),
         {:ok, commit} <- signed_commit(did, private_key, root, current.prev_cid, current.rev),
         {:ok, commit_bytes} <- Commit.encode(commit),
         {:ok, commit_cid} <- Commit.cid(commit) do
      inserted_at = Timestamp.iso8601_utc()

      {:ok,
       %{
         rev: commit.rev,
         prev_cid: current.commit_cid,
         root_cid: Cid.to_string(root),
         commit_cid: Cid.to_string(commit_cid),
         commit_bytes: commit_bytes,
         inserted_at: inserted_at,
         row_ops: prepared.row_ops,
         results: Enum.reverse(prepared.results),
         paths: Enum.reverse(prepared.paths),
         ops: Enum.reverse(prepared.ops),
         blocks: Enum.reverse(prepared.blocks) ++ mst_blocks ++ [{commit_cid, commit_bytes}]
       }}
    end
  end

  defp prepare_apply_writes(conn, did, current, writes) do
    entries = Map.new(current.entries, fn {path, cid} -> {path, cid} end)

    initial = %{
      entries: entries,
      row_ops: [],
      results: [],
      paths: [],
      ops: [],
      blocks: []
    }

    writes
    |> Enum.reduce_while({:ok, initial}, fn write, {:ok, acc} ->
      case prepare_apply_write(conn, did, write, acc) do
        {:ok, acc} -> {:cont, {:ok, acc}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp prepare_apply_write(_conn, did, %{action: :create} = write, acc) do
    path = write.collection <> "/" <> write.rkey

    if Map.has_key?(acc.entries, path) do
      {:error, :duplicate_record}
    else
      with {:ok, record_cid, record_bytes} <- encode_record(write.record) do
        uri = "at://" <> did <> "/" <> path
        record_cid_string = Cid.to_string(record_cid)

        {:ok,
         %{
           acc
           | entries: Map.put(acc.entries, path, record_cid),
             row_ops: [{:upsert, write, path, record_cid_string} | acc.row_ops],
             results: [
               %{action: :create, uri: uri, cid: record_cid_string, validationStatus: write.validation_status}
               | acc.results
             ],
             paths: [path | acc.paths],
             ops: [%{"action" => "create", "path" => path, "cid" => record_cid_string} | acc.ops],
             blocks: [{record_cid, record_bytes} | acc.blocks]
         }}
      end
    end
  end

  defp prepare_apply_write(conn, did, %{action: :update} = write, acc) do
    path = write.collection <> "/" <> write.rkey

    if Map.has_key?(acc.entries, path) do
      with {:ok, existing_record} <- current_record(conn, write.collection, write.rkey),
           {:ok, record_cid, record_bytes} <- encode_record(write.record) do
        uri = "at://" <> did <> "/" <> path
        record_cid_string = Cid.to_string(record_cid)
        op = %{"action" => "update", "path" => path, "cid" => record_cid_string}
        op = if existing_record, do: Map.put(op, "prev", existing_record.cid), else: op

        {:ok,
         %{
           acc
           | entries: Map.put(acc.entries, path, record_cid),
             row_ops: [{:upsert, write, path, record_cid_string} | acc.row_ops],
             results: [
               %{action: :update, uri: uri, cid: record_cid_string, validationStatus: write.validation_status}
               | acc.results
             ],
             paths: [path | acc.paths],
             ops: [op | acc.ops],
             blocks: [{record_cid, record_bytes} | acc.blocks]
         }}
      end
    else
      {:error, :record_not_found}
    end
  end

  defp prepare_apply_write(_conn, _did, %{action: :delete} = write, acc) do
    path = write.collection <> "/" <> write.rkey

    if Map.has_key?(acc.entries, path) do
      previous_cid = acc.entries |> Map.fetch!(path) |> Cid.to_string()

      {:ok,
       %{
         acc
         | entries: Map.delete(acc.entries, path),
           row_ops: [{:delete, write} | acc.row_ops],
           results: [%{action: :delete} | acc.results],
           paths: [path | acc.paths],
           ops: [%{"action" => "delete", "path" => path, "cid" => nil, "prev" => previous_cid} | acc.ops]
       }}
    else
      {:ok, %{acc | results: [%{action: :delete} | acc.results]}}
    end
  end

  defp encode_record(record) do
    with {:ok, record_bytes} <- Drisl.encode(record) do
      {:ok, Cid.for_drisl(record_bytes), record_bytes}
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

  defp apply_write_rows(conn, repo) do
    repo.row_ops
    |> Enum.reverse()
    |> Enum.reduce_while(:ok, fn
      {:upsert, write, path, record_cid}, :ok ->
        row = %{
          collection: write.collection,
          rkey: write.rkey,
          path: path,
          record_cid: record_cid,
          record: write.record,
          inserted_at: repo.inserted_at
        }

        case upsert_record(conn, row) do
          :ok -> {:cont, :ok}
          {:error, reason} -> {:halt, {:error, reason}}
        end

      {:delete, write}, :ok ->
        case delete_record_row(conn, write.collection, write.rkey) do
          :ok -> {:cont, :ok}
          {:error, reason} -> {:halt, {:error, reason}}
        end
    end)
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
