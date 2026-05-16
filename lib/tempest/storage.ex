defmodule Tempest.Storage do
  @moduledoc """
  Boots the SQLite-first storage layout used by Tempest.
  """

  alias Exqlite.Sqlite3
  alias Tempest.Config

  @sqlite_bootstrap """
  PRAGMA journal_mode = WAL;
  PRAGMA busy_timeout = 5000;
  """

  @account_schema """
  CREATE TABLE IF NOT EXISTS blob_metadata (
    did TEXT NOT NULL,
    cid TEXT NOT NULL,
    mime_type TEXT NOT NULL,
    size INTEGER NOT NULL CHECK (size >= 0),
    state TEXT NOT NULL CHECK (state IN ('temp', 'public')),
    inserted_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    temp_expires_at TEXT,
    referenced_at TEXT,
    PRIMARY KEY (did, cid)
  );

  CREATE INDEX IF NOT EXISTS blob_metadata_did_state_cid_idx ON blob_metadata (did, state, cid);
  CREATE INDEX IF NOT EXISTS blob_metadata_state_temp_expires_at_idx ON blob_metadata (state, temp_expires_at);
  """

  @sequencer_schema """
  CREATE TABLE IF NOT EXISTS repo_seq (
    seq INTEGER PRIMARY KEY AUTOINCREMENT,
    did TEXT NOT NULL,
    event_type TEXT NOT NULL,
    rev TEXT,
    commit_cid TEXT,
    event_cbor BLOB NOT NULL,
    created_at TEXT NOT NULL
  );

  CREATE INDEX IF NOT EXISTS repo_seq_did_seq_idx ON repo_seq (did, seq);
  CREATE INDEX IF NOT EXISTS repo_seq_event_type_seq_idx ON repo_seq (event_type, seq);
  CREATE INDEX IF NOT EXISTS repo_seq_rev_idx ON repo_seq (rev);
  CREATE INDEX IF NOT EXISTS repo_seq_commit_cid_idx ON repo_seq (commit_cid);
  """

  @doc """
  Creates the Tempest data directory layout and initializes SQLite files.
  """
  def bootstrap!(%Config{} = config) do
    File.mkdir_p!(config.data_dir)
    Enum.each(Config.data_dirs(config), &File.mkdir_p!/1)

    config
    |> Config.account_db_path()
    |> bootstrap_sqlite_file!(@account_schema)

    config
    |> Config.sequencer_db_path()
    |> bootstrap_sqlite_file!(@sequencer_schema)

    :ok
  end

  @doc """
  Returns public storage readiness metadata for health responses.
  """
  def health(%Config{} = config, env) do
    account_db = Config.account_db_path(config)
    sequencer_db = Config.sequencer_db_path(config)

    %{
      "dataDir" => public_path(config.data_dir, env),
      "accountDb" => public_path(account_db, env),
      "sequencerDb" => public_path(sequencer_db, env),
      "writable" => writable?(config.data_dir) and File.exists?(account_db) and File.exists?(sequencer_db)
    }
  end

  defp bootstrap_sqlite_file!(path, schema) do
    File.mkdir_p!(Path.dirname(path))

    with {:ok, conn} <- Sqlite3.open(path),
         :ok <- Sqlite3.execute(conn, @sqlite_bootstrap <> schema),
         :ok <- Sqlite3.close(conn) do
      :ok
    else
      {:error, reason} ->
        raise RuntimeError, "failed to bootstrap SQLite database #{path}: #{reason}"
    end
  end

  defp writable?(data_dir) do
    test_path = Path.join(data_dir, ".writable")

    case File.write(test_path, "ok") do
      :ok ->
        File.rm(test_path)
        true

      {:error, _reason} ->
        false
    end
  end

  defp public_path(path, :prod), do: Path.basename(path)
  defp public_path(path, _env), do: path
end
