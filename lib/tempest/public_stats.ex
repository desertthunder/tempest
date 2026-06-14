defmodule Tempest.PublicStats do
  @moduledoc """
  Sanitized aggregate stats for public dashboards and automation.
  """

  import Ecto.Query

  alias Tempest.Accounts.Account
  alias Tempest.Storage.Timestamp
  alias Tempest.{Config, Repo, RepoStorage, Sequencer, Storage}

  @user_limit 12
  @collection_limit 10
  @commit_week_limit 4

  @doc """
  Returns public aggregate stats without admin-only fields or local paths.
  """
  def summary(opts \\ []) do
    config = Keyword.get_lazy(opts, :config, &Config.load!/0)
    accounts = hosted_accounts(@user_limit)
    week_ranges = commit_week_ranges()
    repo_scan = scan_repos(config)
    details = scan_details(accounts, week_ranges, config)
    health = health(config, repo_scan.error_count + details.error_count)

    %{
      "status" => health["status"],
      "version" => Tempest.version(),
      "generatedAt" => Timestamp.iso8601_utc(),
      "uptimeSeconds" => uptime_seconds(),
      "metrics" => metrics(repo_scan),
      "users" => details.users,
      "latestRecord" => details.latest_record,
      "commitWeeks" => commit_weeks(week_ranges, details.commit_week_counts),
      "collections" => collection_summaries(details.collections),
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

  defp scan_details(accounts, week_ranges, config) do
    week_starts = Enum.map(week_ranges, & &1.week_start)

    accounts
    |> Enum.reduce(empty_detail_scan(), fn account, acc ->
      case repo_status_counts(account.did, config) do
        {:ok, counts} ->
          scan_account_details(account, counts, week_starts, config, acc)

        {:error, _reason} ->
          acc
      end
    end)
    |> Map.update!(:users, &Enum.reverse/1)
  end

  defp scan_account_details(account, counts, week_starts, config, acc) do
    with {:ok, profile} <- repo_profile_blobs(account.did, config),
         {:ok, latest_record} <- repo_latest_public_record(account.did, config),
         {:ok, commit_week_counts} <- repo_commit_week_counts(account.did, week_starts, config),
         {:ok, collection_summaries} <- repo_collection_summaries(account.did, config) do
      user = public_user(account, counts, profile)

      %{
        acc
        | users: [user | acc.users],
          latest_record: newest_record(acc.latest_record, public_latest_record(account, latest_record)),
          commit_week_counts: merge_counts(acc.commit_week_counts, commit_week_counts),
          collections: collection_summaries ++ acc.collections
      }
    else
      {:error, _reason} ->
        %{acc | error_count: acc.error_count + 1}
    end
  end

  defp empty_detail_scan do
    %{users: [], latest_record: nil, commit_week_counts: %{}, collections: [], error_count: 0}
  end

  defp public_user(account, counts, profile) do
    %{
      "did" => account.did,
      "handle" => account.handle,
      "status" => account.status,
      "recordCount" => Map.get(counts, :record_count, 0),
      "lastIndexedAt" => Map.get(counts, :latest_activity_at),
      "avatarUrl" => blob_url(account.did, Map.get(profile, :avatar_cid)),
      "bannerUrl" => blob_url(account.did, Map.get(profile, :banner_cid))
    }
  end

  defp public_latest_record(_account, nil), do: nil

  defp public_latest_record(account, record) do
    %{
      "did" => account.did,
      "handle" => account.handle,
      "collection" => record.collection,
      "rkey" => record.rkey,
      "cid" => record.cid,
      "indexedAt" => record.indexed_at
    }
  end

  defp newest_record(nil, record), do: record
  defp newest_record(record, nil), do: record

  defp newest_record(%{"indexedAt" => left} = current, %{"indexedAt" => right} = candidate) do
    if right > left, do: candidate, else: current
  end

  defp merge_counts(left, right) do
    Map.merge(left, right, fn _key, left_count, right_count -> left_count + right_count end)
  end

  defp commit_week_ranges do
    current_week_start =
      Date.utc_today()
      |> week_start()

    0..(@commit_week_limit - 1)
    |> Enum.map(fn offset -> Date.add(current_week_start, -7 * offset) end)
    |> Enum.reverse()
    |> Enum.map(fn week_start -> %{week_start: week_start, week_end: Date.add(week_start, 6)} end)
  end

  defp commit_weeks(week_ranges, counts) do
    Enum.map(week_ranges, fn range ->
      %{
        "weekStart" => Date.to_iso8601(range.week_start),
        "weekEnd" => Date.to_iso8601(range.week_end),
        "commitCount" => Map.get(counts, range.week_start, 0)
      }
    end)
  end

  defp collection_summaries(summaries) do
    summaries
    |> Enum.reduce(%{}, fn summary, acc ->
      Map.update(acc, summary.collection, summary.record_count, &(&1 + summary.record_count))
    end)
    |> Enum.map(fn {collection, record_count} -> %{"collection" => collection, "recordCount" => record_count} end)
    |> Enum.sort_by(fn summary -> {-summary["recordCount"], summary["collection"]} end)
    |> Enum.take(@collection_limit)
  end

  defp week_start(date), do: Date.add(date, 1 - Date.day_of_week(date))

  defp hosted_accounts(limit) do
    Account
    |> where([a], a.active == true and a.status == "active")
    |> order_by([a], asc: a.handle, asc: a.did)
    |> limit(^limit)
    |> Repo.all()
  end

  defp blob_url(_did, nil), do: nil

  defp blob_url(did, cid) when is_binary(did) and is_binary(cid) do
    "/xrpc/com.atproto.sync.getBlob?" <> URI.encode_query(%{"did" => did, "cid" => cid})
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

  defp repo_profile_blobs(did, config) do
    RepoStorage.public_profile_blobs(did, config)
  rescue
    _error -> {:error, :repo_profile_failed}
  catch
    _kind, _reason -> {:error, :repo_profile_failed}
  end

  defp repo_latest_public_record(did, config) do
    RepoStorage.latest_public_record(did, config)
  rescue
    _error -> {:error, :repo_latest_record_failed}
  catch
    _kind, _reason -> {:error, :repo_latest_record_failed}
  end

  defp repo_commit_week_counts(did, week_starts, config) do
    RepoStorage.commit_week_counts(did, week_starts, config)
  rescue
    _error -> {:error, :repo_commit_weeks_failed}
  catch
    _kind, _reason -> {:error, :repo_commit_weeks_failed}
  end

  defp repo_collection_summaries(did, config) do
    RepoStorage.collection_summaries(did, config)
  rescue
    _error -> {:error, :repo_collection_summaries_failed}
  catch
    _kind, _reason -> {:error, :repo_collection_summaries_failed}
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
