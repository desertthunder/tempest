defmodule Tempest.RepoStorage do
  @moduledoc """
  SQLite storage boundary for one hosted account repository.
  """

  alias Exqlite.Sqlite3
  alias Tempest.Accounts.Account
  alias Tempest.Config
  alias Tempest.Identity.KeyStore
  alias Tempest.Identity.SigningKey
  alias Tempest.RepoCore.{Cid, Commit, Did, Mst, Tid}

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
    rev = Tid.new!(Tid.now_unix_microseconds(), random_clock_id())

    with {:ok, %{root: root, blocks: mst_blocks}} <- Mst.serialize(Mst.new()),
         {:ok, unsigned_commit} <- Commit.new(did: did, data: root, rev: rev, prev: nil),
         {:ok, commit} <- Commit.sign(unsigned_commit, private_key),
         {:ok, commit_bytes} <- Commit.encode(commit),
         {:ok, commit_cid} <- Commit.cid(commit) do
      inserted_at = timestamp()

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
      {{:error, reason}, :ok} -> {:error, reason}
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

      case execute(conn, "INSERT INTO blocks (cid, codec, bytes, inserted_at) VALUES (?1, ?2, ?3, ?4)", [
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
        nil,
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

  defp random_clock_id do
    <<value::16>> = :crypto.strong_rand_bytes(2)
    rem(value, Tid.max_clock_id() + 1)
  end

  defp timestamp do
    DateTime.utc_now()
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
  end
end
