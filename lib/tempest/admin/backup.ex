defmodule Tempest.Admin.Backup do
  @moduledoc """
  Local SQLite-first backup and restore helpers.

  Backups are directories containing the durable Tempest files. Restore refuses
  to overwrite an existing target unless `force?: true` is passed.
  """

  alias Tempest.Config

  @manifest "manifest.json"

  def create(opts \\ []) do
    config = Keyword.get(opts, :config, Config.load!())
    backup_dir = Keyword.get(opts, :path) || default_backup_dir(config)
    upload? = Keyword.get(opts, :upload?, false)

    with :ok <- File.mkdir_p(backup_dir),
         :ok <- checkpoint_sqlite_files(config),
         :ok <- copy_existing(config, backup_dir),
         :ok <- write_manifest(config, backup_dir),
         {:ok, upload} <- maybe_upload(backup_dir, upload?) do
      {:ok, %{path: backup_dir, upload: upload}}
    end
  end

  def restore(backup_dir, opts \\ []) when is_binary(backup_dir) do
    config = Keyword.get(opts, :config, Config.load!())
    target_dir = Keyword.get(opts, :target) || config.data_dir
    force? = Keyword.get(opts, :force?, false)

    with :ok <- ensure_backup_dir(backup_dir),
         :ok <- ensure_restore_target(target_dir, force?),
         :ok <- File.mkdir_p(target_dir),
         :ok <- copy_backup_contents(backup_dir, target_dir) do
      {:ok, %{path: target_dir}}
    end
  end

  defp default_backup_dir(%Config{data_dir: data_dir}) do
    stamp = DateTime.utc_now() |> DateTime.to_iso8601(:basic) |> String.replace(~r/[^0-9A-Za-z]/, "")
    suffix = System.unique_integer([:positive])
    Path.join([data_dir, "backups", "tempest-backup-#{stamp}-#{suffix}"])
  end

  defp checkpoint_sqlite_files(config) do
    config
    |> sqlite_paths()
    |> Enum.reduce_while(:ok, fn path, :ok ->
      case checkpoint_sqlite(path) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp sqlite_paths(config) do
    repo_paths =
      config.data_dir
      |> Path.join("repos")
      |> sqlite_files()

    [Config.account_db_path(config), Config.sequencer_db_path(config) | repo_paths]
    |> Enum.uniq()
    |> Enum.filter(&File.exists?/1)
  end

  defp sqlite_files(dir) do
    if File.dir?(dir) do
      dir
      |> File.ls!()
      |> Enum.filter(&String.ends_with?(&1, ".sqlite"))
      |> Enum.map(&Path.join(dir, &1))
    else
      []
    end
  end

  defp checkpoint_sqlite(path) do
    with {:ok, conn} <- Exqlite.Sqlite3.open(path),
         :ok <- Exqlite.Sqlite3.execute(conn, "PRAGMA wal_checkpoint(TRUNCATE)"),
         :ok <- Exqlite.Sqlite3.close(conn) do
      :ok
    else
      {:error, reason} -> {:error, {:sqlite_checkpoint, path, reason}}
    end
  end

  defp maybe_upload(_backup_dir, false), do: {:ok, nil}

  defp maybe_upload(backup_dir, true) do
    backup_config = Application.get_env(:tempest, __MODULE__, [])

    case Keyword.get(backup_config, :store, :local) do
      :s3 -> upload_s3_backup(backup_dir, Keyword.fetch!(backup_config, :s3))
      "s3" -> upload_s3_backup(backup_dir, Keyword.fetch!(backup_config, :s3))
      _local -> {:error, :backup_store_not_configured}
    end
  rescue
    e in KeyError -> {:error, {:missing_backup_config, e.key}}
  end

  defp upload_s3_backup(backup_dir, s3_config) do
    archive_path = backup_dir <> ".zip"
    key = Keyword.get(s3_config, :key) || "backups/" <> Path.basename(archive_path)

    with {:ok, archive_path} <- archive_backup(backup_dir, archive_path),
         {:ok, uploaded} <- Tempest.Admin.S3BackupStorage.upload_file(s3_config, key, archive_path) do
      {:ok, Map.put(uploaded, :archive_path, archive_path)}
    end
  end

  defp archive_backup(backup_dir, archive_path) do
    files = zip_files(backup_dir)

    archive = String.to_charlist(archive_path)
    zip_entries = Enum.map(files, fn {relative, path} -> {String.to_charlist(relative), File.read!(path)} end)

    case :zip.create(archive, zip_entries) do
      {:ok, _archive} -> {:ok, archive_path}
      {:error, reason} -> {:error, {:zip_create, reason}}
    end
  end

  defp zip_files(backup_dir) do
    backup_dir
    |> files_under()
    |> Enum.map(fn path -> {Path.relative_to(path, backup_dir), path} end)
  end

  defp files_under(dir) do
    dir
    |> File.ls!()
    |> Enum.flat_map(fn entry ->
      path = Path.join(dir, entry)
      if File.dir?(path), do: files_under(path), else: [path]
    end)
  end

  defp copy_existing(config, backup_dir) do
    entries = [
      "account.sqlite",
      "account.sqlite-wal",
      "account.sqlite-shm",
      "sequencer.sqlite",
      "sequencer.sqlite-wal",
      "sequencer.sqlite-shm",
      "repos",
      "blobs",
      "oauth_jwks.json"
    ]

    Enum.reduce_while(entries, :ok, fn entry, :ok ->
      source = Path.join(config.data_dir, entry)
      target = Path.join(backup_dir, entry)

      case copy_path_if_exists(source, target) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp copy_path_if_exists(source, target) do
    cond do
      File.dir?(source) ->
        copy_dir(source, target)

      File.regular?(source) ->
        File.mkdir_p!(Path.dirname(target))
        File.cp(source, target)

      true ->
        :ok
    end
  end

  defp copy_dir(source, target) do
    with :ok <- File.mkdir_p(target),
         {:ok, entries} <- File.ls(source) do
      Enum.reduce_while(entries, :ok, fn entry, :ok ->
        case copy_path_if_exists(Path.join(source, entry), Path.join(target, entry)) do
          :ok -> {:cont, :ok}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
    end
  end

  defp write_manifest(config, backup_dir) do
    manifest = %{
      "version" => 1,
      "createdAt" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "sourceDataDir" => config.data_dir,
      "contains" => backup_entries(backup_dir)
    }

    File.write(Path.join(backup_dir, @manifest), Jason.encode!(manifest, pretty: true))
  end

  defp backup_entries(backup_dir) do
    backup_dir
    |> File.ls!()
    |> Enum.reject(&(&1 == @manifest))
    |> Enum.sort()
  end

  defp ensure_backup_dir(path) do
    cond do
      not File.dir?(path) -> {:error, :backup_not_found}
      not File.exists?(Path.join(path, @manifest)) -> {:error, :backup_manifest_missing}
      true -> :ok
    end
  end

  defp ensure_restore_target(target_dir, true), do: File.rm_rf(target_dir) |> ok_rm_rf()

  defp ensure_restore_target(target_dir, false) do
    account_db = Path.join(target_dir, "account.sqlite")
    sequencer_db = Path.join(target_dir, "sequencer.sqlite")

    if File.exists?(account_db) or File.exists?(sequencer_db) do
      {:error, :target_not_empty}
    else
      :ok
    end
  end

  defp copy_backup_contents(backup_dir, target_dir) do
    backup_dir
    |> File.ls!()
    |> Enum.reject(&(&1 == @manifest))
    |> Enum.reduce_while(:ok, fn entry, :ok ->
      case copy_path_if_exists(Path.join(backup_dir, entry), Path.join(target_dir, entry)) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp ok_rm_rf({:ok, _files}), do: :ok
  defp ok_rm_rf({:error, _file, reason}), do: {:error, reason}
end
