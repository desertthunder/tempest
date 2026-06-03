defmodule Tempest.Sync do
  @moduledoc """
  Read-side context for `com.atproto.sync.*` XRPC methods.
  """

  import Ecto.Query

  alias Tempest.Accounts.Account
  alias Tempest.Blobs
  alias Tempest.Config
  alias Tempest.Repo
  alias Tempest.RepoCore.{Cid, Did, Nsid, RecordKey}
  alias Tempest.RepoStorage

  @request_crawl_table :tempest_request_crawl_limits

  def get_repo(params) when is_map(params) do
    with {:ok, did} <- validate_did_param(params),
         {:ok, account} <- fetch_account(did),
         :ok <- ensure_active(account),
         {:ok, export} <- RepoStorage.export_car(account.did) do
      {:ok, export.bytes}
    end
  end

  def get_repo(_params), do: {:error, :invalid_request_body}

  def get_latest_commit(params) when is_map(params) do
    with {:ok, did} <- validate_did_param(params),
         {:ok, account} <- fetch_account(did),
         :ok <- ensure_active(account),
         {:ok, latest} <- RepoStorage.latest_commit(account.did) do
      {:ok, %{cid: latest.cid, rev: latest.rev}}
    end
  end

  def get_latest_commit(_params), do: {:error, :invalid_request_body}

  def get_record(params) when is_map(params) do
    with {:ok, input} <- validate_get_record_params(params),
         {:ok, account} <- fetch_account(input.did),
         :ok <- ensure_active(account),
         {:ok, export} <-
           RepoStorage.export_record_car(account.did, input.collection, input.rkey, commit: input.commit) do
      {:ok, export.bytes}
    end
  end

  def get_record(_params), do: {:error, :invalid_request_body}

  def get_blocks(params) when is_map(params) do
    with {:ok, input} <- validate_get_blocks_params(params),
         {:ok, account} <- fetch_account(input.did),
         :ok <- ensure_active(account),
         {:ok, export} <- RepoStorage.export_blocks_car(account.did, input.cids) do
      {:ok, export.bytes}
    end
  end

  def get_blocks(_params), do: {:error, :invalid_request_body}

  def get_repo_status(params) when is_map(params) do
    with {:ok, did} <- validate_did_param(params),
         {:ok, account} <- fetch_account(did, active_required?: false) do
      repo_status(account)
    end
  end

  def get_repo_status(_params), do: {:error, :invalid_request_body}

  def list_repos(params) when is_map(params) do
    with {:ok, limit} <- validate_limit(Map.get(params, "limit"), 500),
         {:ok, cursor} <- validate_optional_cursor(Map.get(params, "cursor")) do
      repos =
        Account
        |> order_by([account], asc: account.did)
        |> Repo.all()
        |> Enum.drop_while(fn account -> cursor && account.did <= cursor end)
        |> Enum.take(limit + 1)

      visible = Enum.take(repos, limit)

      response = %{
        repos: Enum.map(visible, &repo_listing/1)
      }

      if length(repos) > limit do
        {:ok, Map.put(response, :cursor, List.last(visible).did)}
      else
        {:ok, response}
      end
    end
  end

  def list_repos(_params), do: {:error, :invalid_request_body}

  def list_blobs(params) when is_map(params) do
    with {:ok, did} <- validate_did_param(params),
         {:ok, limit} <- validate_limit(Map.get(params, "limit"), 500),
         {:ok, cursor} <- validate_optional_cursor(Map.get(params, "cursor")),
         {:ok, account} <- fetch_account(did),
         :ok <- ensure_active(account),
         {:ok, page} <- Blobs.list_public(account.did, limit: limit, cursor: cursor) do
      {:ok, page}
    end
  end

  def list_blobs(_params), do: {:error, :invalid_request_body}

  def get_blob(params) when is_map(params) do
    with {:ok, input} <- validate_get_blob_params(params),
         {:ok, account} <- fetch_account(input.did),
         :ok <- ensure_active(account),
         {:ok, metadata} <- Blobs.get_public_metadata(account.did, input.cid),
         {:ok, response} <- blob_response(account.did, input.cid, metadata) do
      {:ok, response}
    end
  end

  def get_blob(_params), do: {:error, :invalid_request_body}

  def request_crawl(params) when is_map(params) do
    with {:ok, hostname} <- validate_request_crawl_hostname(Map.get(params, "hostname")),
         :ok <- check_request_crawl_rate(hostname),
         {:ok, result} <- request_configured_relays(hostname) do
      :telemetry.execute([:tempest, :sync, :request_crawl], %{relay_count: result.requested}, %{
        hostname: hostname,
        skipped: result.skipped
      })

      {:ok, %{}}
    end
  end

  def request_crawl(_params), do: {:error, :invalid_request_body}

  defp validate_get_record_params(params) do
    with {:ok, did} <- validate_did_param(params),
         {:ok, collection} <- validate_collection(Map.get(params, "collection")),
         {:ok, rkey} <- validate_rkey(Map.get(params, "rkey")),
         {:ok, commit} <- validate_optional_commit(Map.get(params, "commit")) do
      {:ok, %{did: did, collection: collection, rkey: rkey, commit: commit}}
    end
  end

  defp validate_get_blocks_params(params) do
    with {:ok, did} <- validate_did_param(params),
         {:ok, cids} <- validate_cid_list(Map.get(params, "cids")) do
      {:ok, %{did: did, cids: cids}}
    end
  end

  defp validate_get_blob_params(params) do
    with {:ok, did} <- validate_did_param(params),
         {:ok, cid} <- validate_cid_param(Map.get(params, "cid")) do
      {:ok, %{did: did, cid: cid}}
    end
  end

  defp validate_cid_param(nil), do: {:error, {:missing_field, "cid"}}

  defp validate_cid_param(cid) when is_binary(cid) do
    if Cid.valid?(cid), do: {:ok, cid}, else: {:error, :invalid_cid}
  end

  defp validate_cid_param(_cid), do: {:error, :invalid_cid}

  defp validate_did_param(params) do
    case Map.get(params, "did") do
      did when is_binary(did) and did != "" ->
        case Did.parse(did) do
          {:ok, did} -> {:ok, did}
          {:error, _reason} -> {:error, :invalid_did}
        end

      _value ->
        {:error, {:missing_field, "did"}}
    end
  end

  defp validate_collection(collection) do
    case Nsid.parse(collection) do
      {:ok, %Nsid{value: normalized}} -> {:ok, normalized}
      {:error, _reason} -> {:error, :invalid_collection}
    end
  end

  defp validate_rkey(rkey) do
    case RecordKey.parse(rkey) do
      {:ok, rkey} -> {:ok, rkey}
      {:error, _reason} -> {:error, :invalid_rkey}
    end
  end

  defp validate_optional_commit(nil), do: {:ok, nil}

  defp validate_optional_commit(commit) do
    case Cid.parse(commit) do
      {:ok, _cid} -> {:ok, commit}
      {:error, _reason} -> {:error, :invalid_commit}
    end
  end

  defp validate_cid_list(nil), do: {:error, {:missing_field, "cids"}}
  defp validate_cid_list([]), do: {:error, :invalid_cids}

  defp validate_cid_list(cids) when is_list(cids) do
    cids
    |> Enum.flat_map(&split_cid_value/1)
    |> validate_cid_values()
  end

  defp validate_cid_list(cids) when is_binary(cids) do
    cids
    |> split_cid_value()
    |> validate_cid_values()
  end

  defp validate_cid_list(_cids), do: {:error, :invalid_cids}

  defp split_cid_value(value) when is_binary(value) do
    value
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
  end

  defp split_cid_value(_value), do: []

  defp validate_cid_values([]), do: {:error, :invalid_cids}

  defp validate_cid_values(cids) when length(cids) <= 100 do
    if Enum.all?(cids, &Cid.valid?/1) do
      {:ok, Enum.uniq(cids)}
    else
      {:error, :invalid_cids}
    end
  end

  defp validate_cid_values(_cids), do: {:error, :invalid_cids}

  defp validate_limit(nil, default), do: {:ok, default}

  defp validate_limit(limit, _default) when is_integer(limit) and limit in 1..1_000, do: {:ok, limit}

  defp validate_limit(limit, default) when is_binary(limit) do
    case Integer.parse(limit) do
      {limit, ""} -> validate_limit(limit, default)
      _invalid -> {:error, :invalid_limit}
    end
  end

  defp validate_limit(_limit, _default), do: {:error, :invalid_limit}

  defp validate_optional_cursor(nil), do: {:ok, nil}
  defp validate_optional_cursor(cursor) when is_binary(cursor) and cursor != "", do: {:ok, cursor}
  defp validate_optional_cursor(_cursor), do: {:error, :invalid_cursor}

  defp ensure_blob_size(%{content_length: size}, %{size: size}), do: :ok
  defp ensure_blob_size(_blob, _metadata), do: {:error, :blob_not_found}

  defp blob_response(did, cid, metadata) do
    case Blobs.cdn_url(did, cid) do
      {:ok, url} ->
        {:ok, %{redirect: url, cid: cid}}

      :disabled ->
        with {:ok, blob} <- Blobs.get_blob(Config.load!(), did, cid, metadata.mime_type),
             :ok <- ensure_blob_size(blob, metadata) do
          {:ok, Map.put(blob, :cid, cid)}
        end
    end
  end

  defp validate_request_crawl_hostname(hostname) when is_binary(hostname) do
    configured = Tempest.Config.load!().hostname
    hostname = String.trim(hostname)

    cond do
      hostname == "" ->
        {:error, {:missing_field, "hostname"}}

      hostname != configured ->
        {:error, :invalid_hostname}

      String.contains?(hostname, ["://", "/", "\\", " "]) ->
        {:error, :invalid_hostname}

      true ->
        {:ok, hostname}
    end
  end

  defp validate_request_crawl_hostname(_hostname), do: {:error, {:missing_field, "hostname"}}

  defp check_request_crawl_rate(hostname) do
    table = request_crawl_table()
    now = System.monotonic_time(:millisecond)
    window_ms = request_crawl_window_ms()

    case :ets.lookup(table, hostname) do
      [{^hostname, last_seen}] when now - last_seen < window_ms ->
        {:error, :rate_limited}

      _other ->
        :ets.insert(table, {hostname, now})
        :ok
    end
  end

  defp request_crawl_table do
    case :ets.whereis(@request_crawl_table) do
      :undefined ->
        try do
          :ets.new(@request_crawl_table, [:named_table, :public, :set])
        rescue
          ArgumentError -> @request_crawl_table
        end

      _tid ->
        @request_crawl_table
    end
  end

  defp request_crawl_window_ms do
    :tempest
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:request_crawl_window_ms, 60_000)
  end

  defp request_configured_relays(hostname) do
    relays =
      :tempest
      |> Application.get_env(__MODULE__, [])
      |> Keyword.get(:relays, [])
      |> Enum.uniq()

    req_options =
      :tempest
      |> Application.get_env(__MODULE__, [])
      |> Keyword.get(:http_req_options, [])

    Enum.reduce_while(relays, {:ok, %{requested: 0, skipped: 0}}, fn relay, {:ok, acc} ->
      case request_relay_crawl(relay, hostname, req_options) do
        :ok -> {:cont, {:ok, %{acc | requested: acc.requested + 1}}}
        {:skip, _reason} -> {:cont, {:ok, %{acc | skipped: acc.skipped + 1}}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp request_relay_crawl(relay, hostname, req_options) when is_binary(relay) do
    case relay_url(relay) do
      {:ok, url} ->
        request =
          Keyword.merge(req_options,
            url: url,
            json: %{"hostname" => hostname},
            retry: false
          )

        case Req.post(request) do
          {:ok, %{status: status}} when status in 200..299 -> :ok
          {:ok, %{status: status}} -> {:error, {:relay_status, status}}
          {:error, reason} -> {:error, {:relay_request_failed, reason}}
        end

      {:error, reason} ->
        {:skip, reason}
    end
  end

  defp request_relay_crawl(_relay, _hostname, _req_options), do: {:skip, :invalid_relay}

  defp relay_url(relay) do
    relay = String.trim_trailing(relay, "/")
    uri = URI.parse(relay)

    if uri.scheme in ["http", "https"] and is_binary(uri.host) and uri.host != "" do
      {:ok, relay <> "/xrpc/com.atproto.sync.requestCrawl"}
    else
      {:error, :invalid_relay}
    end
  end

  defp fetch_account(did, opts \\ []) do
    active_required? = Keyword.get(opts, :active_required?, true)

    Account
    |> where([account], account.did == ^did)
    |> Repo.one()
    |> case do
      %Account{} = account when active_required? -> ensure_found_active(account)
      %Account{} = account -> {:ok, account}
      nil -> {:error, :repo_not_found}
    end
  end

  defp ensure_found_active(%Account{} = account) do
    case ensure_active(account) do
      :ok -> {:ok, account}
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensure_active(%Account{active: true, status: "active"}), do: :ok
  defp ensure_active(%Account{status: "takendown"}), do: {:error, :repo_takendown}
  defp ensure_active(%Account{status: "suspended"}), do: {:error, :repo_suspended}
  defp ensure_active(%Account{status: "deactivated"}), do: {:error, :repo_deactivated}
  defp ensure_active(%Account{status: "deleted"}), do: {:error, :repo_not_found}
  defp ensure_active(%Account{}), do: {:error, :repo_not_found}

  defp repo_status(%Account{} = account) do
    response = %{did: account.did, active: account.active and account.status == "active"}

    cond do
      response.active ->
        with {:ok, latest} <- RepoStorage.latest_commit(account.did) do
          {:ok, Map.put(response, :rev, latest.rev)}
        end

      account.status in ["active", nil] ->
        {:ok, response}

      true ->
        {:ok, Map.put(response, :status, account.status)}
    end
  end

  defp repo_listing(%Account{} = account) do
    base = %{
      did: account.did,
      active: account.active and account.status == "active",
      status: account.status
    }

    case RepoStorage.latest_commit(account.did) do
      {:ok, latest} -> Map.merge(base, %{head: latest.cid, rev: latest.rev})
      {:error, _reason} -> base
    end
  end
end
