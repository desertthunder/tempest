defmodule Tempest.PersonalBackups.Storage do
  @moduledoc """
  Storage boundary for personal backup snapshot directories and archives.
  """

  alias Tempest.Admin.S3BackupStorage
  alias Tempest.Config

  def finalize_snapshot(%Config{} = config, workspace) when is_map(workspace) do
    if File.exists?(workspace.final_dir) do
      {:error, :snapshot_already_exists}
    else
      with :ok <- File.mkdir_p(Path.dirname(workspace.final_dir)),
           :ok <- File.rename(workspace.temp_dir, workspace.final_dir),
           {:ok, upload} <- maybe_upload_snapshot(config, workspace.storage_key) do
        {:ok,
         workspace
         |> Map.delete(:temp_dir)
         |> Map.put(:storage_upload, upload)}
      end
    end
  end

  def delete_snapshot(%Config{} = config, storage_key) when is_binary(storage_key) do
    config.data_dir
    |> Path.join(storage_key)
    |> File.rm_rf()
    |> case do
      {:ok, _files} -> :ok
      {:error, _file, reason} -> {:error, reason}
    end
  end

  def archive_snapshot(%Config{} = config, storage_key, target_path)
      when is_binary(storage_key) and is_binary(target_path) do
    snapshot_dir = Path.join(config.data_dir, storage_key)

    with true <- File.dir?(snapshot_dir),
         :ok <- File.mkdir_p(Path.dirname(target_path)),
         {:ok, files} <- snapshot_files(snapshot_dir),
         {:ok, archive} <- create_zip(target_path, snapshot_dir, files) do
      {:ok, %{path: archive, byte_size: File.stat!(archive).size}}
    else
      false -> {:error, :snapshot_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp maybe_upload_snapshot(config, storage_key) do
    storage_config = Application.get_env(:tempest, __MODULE__, [])

    case Keyword.get(storage_config, :store, :local) do
      :s3 -> upload_snapshot_archive(config, storage_key, Keyword.fetch!(storage_config, :s3))
      "s3" -> upload_snapshot_archive(config, storage_key, Keyword.fetch!(storage_config, :s3))
      _local -> {:ok, nil}
    end
  rescue
    e in KeyError -> {:error, {:missing_personal_backup_storage_config, e.key}}
  end

  defp upload_snapshot_archive(config, storage_key, s3_config) do
    archive_path = Path.join([config.data_dir, "tmp", Path.basename(storage_key) <> ".zip"])
    key = Keyword.get(s3_config, :key) || storage_key <> ".zip"

    with {:ok, %{path: path, byte_size: byte_size}} <- archive_snapshot(config, storage_key, archive_path),
         {:ok, uploaded} <- S3BackupStorage.upload_file(s3_config, key, path) do
      {:ok, Map.merge(uploaded, %{archive_path: path, archive_bytes: byte_size})}
    end
  end

  defp snapshot_files(snapshot_dir) do
    snapshot_dir
    |> files_under()
    |> case do
      [] -> {:error, :snapshot_empty}
      files -> {:ok, files}
    end
  end

  defp files_under(dir) do
    dir
    |> File.ls!()
    |> Enum.flat_map(fn entry ->
      path = Path.join(dir, entry)
      if File.dir?(path), do: files_under(path), else: [path]
    end)
  end

  defp create_zip(target_path, snapshot_dir, files) do
    archive = String.to_charlist(target_path)

    entries =
      Enum.map(files, fn path ->
        relative = path |> Path.relative_to(snapshot_dir) |> String.to_charlist()
        {relative, File.read!(path)}
      end)

    case :zip.create(archive, entries) do
      {:ok, archive} -> {:ok, List.to_string(archive)}
      {:error, reason} -> {:error, {:zip_create, reason}}
    end
  end
end
