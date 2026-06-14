defmodule Tempest.PublicStats do
  @moduledoc """
  Sanitized aggregate stats for public dashboards and automation.
  """

  import Ecto.Query

  alias Tempest.Accounts.Account
  alias Tempest.Storage.Timestamp
  alias Tempest.{Config, Repo, RepoStorage, Sequencer, Storage}

  @doc """
  Returns public aggregate stats without admin-only fields or local paths.
  """
  def summary(opts \\ []) do
    config = Keyword.get_lazy(opts, :config, &Config.load!/0)
    repo_scan = scan_repos(config)
    health = health(config, repo_scan.error_count)

    %{
      "status" => health["status"],
      "version" => Tempest.version(),
      "generatedAt" => Timestamp.iso8601_utc(),
      "uptimeSeconds" => uptime_seconds(),
      "metrics" => metrics(repo_scan),
      "health" => health
    }
  end

  def uptime_seconds do
    started_at = Tempest.Application.started_at_monotonic()
    max(System.monotonic_time(:second) - started_at, 0)
  end

  defp metrics(repo_scan) do
    %{
      "hostedAccountCount" => hosted_account_count(),
      "totalAccountCount" => total_account_count(),
      "commitCount" => repo_scan.commit_count,
      "collectionCount" => repo_scan.collection_count,
      "recordCount" => repo_scan.record_count,
      "lastIndexedAt" => max_iso8601([repo_scan.latest_activity_at, sequencer_latest_created_at()])
    }
  end

  defp scan_repos(config) do
    Account
    |> where([a], a.active == true and a.status == "active")
    |> select([a], a.did)
    |> Repo.all()
    |> Enum.reduce(empty_repo_scan(), fn did, acc ->
      case repo_status_counts(did, config) do
        {:ok, counts} ->
          %{
            acc
            | commit_count: acc.commit_count + Map.get(counts, :commit_count, 0),
              collection_count: acc.collection_count + Map.get(counts, :collection_count, 0),
              record_count: acc.record_count + Map.get(counts, :record_count, 0),
              latest_activity_at: max_iso8601([acc.latest_activity_at, Map.get(counts, :latest_activity_at)])
          }

        {:error, _reason} ->
          %{acc | error_count: acc.error_count + 1}
      end
    end)
  end

  defp repo_status_counts(did, config) do
    RepoStorage.status_counts(did, config)
  rescue
    _error -> {:error, :repo_stats_failed}
  catch
    _kind, _reason -> {:error, :repo_stats_failed}
  end

  defp empty_repo_scan do
    %{commit_count: 0, collection_count: 0, record_count: 0, latest_activity_at: nil, error_count: 0}
  end

  defp hosted_account_count do
    Account
    |> where([a], a.active == true and a.status == "active")
    |> Repo.aggregate(:count)
  end

  defp total_account_count, do: Repo.aggregate(Account, :count)

  defp health(config, scan_error_count) do
    storage = Storage.health(config, Application.get_env(:tempest, :env, :prod))
    account_database = database_check(Config.account_db_path(config), fn -> Repo.query("SELECT 1", []) end)
    sequencer_database = database_check(Config.sequencer_db_path(config), &Sequencer.current_seq/0)
    torn_write_count = result_or_nil(Sequencer.torn_write_count())

    checks = %{
      "storageWritable" => Map.get(storage, "writable", false),
      "accountDatabase" => account_database,
      "sequencerDatabase" => sequencer_database,
      "repoDirectory" => directory_check(Path.join(config.data_dir, "repos")),
      "blobDirectory" => directory_check(Path.join(config.data_dir, "blobs")),
      "sequencerReadable" => sequencer_database == "ok",
      "tornWriteCount" => torn_write_count,
      "statsScanErrorCount" => scan_error_count
    }

    Map.put(%{"checks" => checks}, "status", health_status(checks))
  end

  defp database_check(path, query) do
    with true <- File.exists?(path),
         {:ok, _result} <- query.() do
      "ok"
    else
      false -> "missing"
      {:error, _reason} -> "error"
    end
  end

  defp directory_check(path) do
    if File.dir?(path), do: "ok", else: "missing"
  end

  defp health_status(
         %{
           "storageWritable" => true,
           "accountDatabase" => "ok",
           "sequencerDatabase" => "ok"
         } = checks
       ) do
    if checks["repoDirectory"] == "ok" and checks["blobDirectory"] == "ok" and
         checks["sequencerReadable"] and checks["tornWriteCount"] == 0 and
         checks["statsScanErrorCount"] == 0 do
      "ok"
    else
      "degraded"
    end
  end

  defp health_status(_checks), do: "unhealthy"

  defp sequencer_latest_created_at do
    case Sequencer.latest_created_at() do
      {:ok, created_at} -> created_at
      {:error, _reason} -> nil
    end
  end

  defp result_or_nil({:ok, value}), do: value
  defp result_or_nil({:error, _reason}), do: nil

  defp max_iso8601(values) do
    values
    |> Enum.reject(&is_nil/1)
    |> Enum.max(fn -> nil end)
  end
end
