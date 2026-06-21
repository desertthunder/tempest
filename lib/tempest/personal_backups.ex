defmodule Tempest.PersonalBackups do
  @moduledoc """
  Registry and identity verification for admin-managed external account backups.
  """

  import Ecto.Query

  alias Tempest.Identity
  alias Tempest.Identity.DidDocument

  alias Tempest.PersonalBackups.{
    Account,
    Credential,
    RetentionSetting,
    Run,
    SecretStore,
    Snapshot,
    SourceClient,
    Storage,
    Verifier
  }

  alias Tempest.Repo
  alias Tempest.RepoCore.{Cid, Drisl}

  @default_blob_concurrency 4
  @transient_retries 2

  def list_accounts do
    Account
    |> order_by([account], asc: account.handle)
    |> Repo.all()
  end

  def get_account!(id), do: Repo.get!(Account, id)
  def get_account_by_did(did) when is_binary(did), do: Repo.get_by(Account, did: did)

  def get_account_with_backup_state!(id) do
    account = Repo.get!(Account, id)
    preload_backup_state(account)
  end

  def preload_backup_state(%Account{} = account) do
    snapshots_query = from(snapshot in Snapshot, order_by: [desc: snapshot.completed_at, desc: snapshot.inserted_at])
    runs_query = from(run in Run, order_by: [desc: run.started_at, desc: run.inserted_at])

    Repo.preload(account, [:credential, :retention_setting, snapshots: {snapshots_query, [:blobs]}, runs: runs_query],
      force: true
    )
  end

  def update_account_profile(%Account{} = account, attrs) when is_map(attrs) do
    account
    |> Account.profile_changeset(stringify_keys(attrs))
    |> Repo.update()
  end

  def delete_account(%Account{} = account), do: Repo.delete(account)

  def list_snapshots(opts \\ []) do
    Snapshot
    |> maybe_filter_snapshots_by_account(Keyword.get(opts, :account))
    |> maybe_filter_snapshots_by_did(Keyword.get(opts, :did))
    |> order_by([snapshot], desc: snapshot.completed_at, desc: snapshot.inserted_at)
    |> Repo.all()
  end

  def get_snapshot!(id), do: Repo.get!(Snapshot, id)

  def account_backup_status(%Account{} = account) do
    latest_snapshot =
      Snapshot
      |> where([snapshot], snapshot.account_id == ^account.id)
      |> order_by([snapshot], desc: snapshot.completed_at, desc: snapshot.inserted_at)
      |> limit(1)
      |> Repo.one()

    latest_run =
      Run
      |> where([run], run.account_id == ^account.id)
      |> order_by([run], desc: run.started_at, desc: run.inserted_at)
      |> limit(1)
      |> Repo.one()

    snapshot_count =
      Snapshot
      |> where([snapshot], snapshot.account_id == ^account.id)
      |> Repo.aggregate(:count)

    stored_blob_count =
      from(blob in Tempest.PersonalBackups.Blob,
        join: snapshot in assoc(blob, :snapshot),
        where: snapshot.account_id == ^account.id and blob.status == "stored"
      )
      |> Repo.aggregate(:count)

    %{
      account: account,
      latest_snapshot: latest_snapshot,
      latest_run: latest_run,
      snapshot_count: snapshot_count,
      stored_blob_count: stored_blob_count
    }
  end

  def credential_public_state(%Account{} = account) do
    account
    |> Repo.preload(:credential, force: true)
    |> Map.fetch!(:credential)
    |> Credential.public_state()
  end

  def rotate_credential(account, mode, secret \\ nil)

  def rotate_credential(%Account{} = account, mode, secret) when mode in ["none", "app_password", "access_token"] do
    with {:ok, credential_attrs} <- credential_attrs(mode, secret) do
      Repo.transaction(fn ->
        credential = account |> Repo.preload(:credential, force: true) |> Map.fetch!(:credential)

        with {:ok, credential} <- Credential.changeset(credential, credential_attrs) |> Repo.update(),
             {:ok, account} <- update_account_credential_state(account, mode) do
          %{account: account, credential: credential}
        else
          {:error, %Ecto.Changeset{} = changeset} -> Repo.rollback(changeset)
        end
      end)
    end
  end

  def rotate_credential(%Account{}, _mode, _secret), do: {:error, :invalid_credential_mode}

  def delete_credential(%Account{} = account), do: rotate_credential(account, "none")

  def decrypted_credential_secret(%Account{} = account) do
    credential = account |> Repo.preload(:credential, force: true) |> Map.fetch!(:credential)

    case credential do
      %Credential{mode: "none"} -> {:ok, nil}
      %Credential{deleted_at: %DateTime{}} -> {:ok, nil}
      %Credential{secret_ciphertext: ciphertext} -> SecretStore.decrypt(ciphertext)
    end
  end

  def register_account(attrs) when is_map(attrs) do
    attrs = stringify_keys(attrs)

    with {:ok, verified_attrs} <- verified_registration_attrs(attrs) do
      Repo.transaction(fn ->
        with {:ok, account} <-
               %Account{}
               |> Account.registration_changeset(verified_attrs)
               |> Repo.insert(),
             {:ok, _credential} <-
               %Credential{}
               |> Credential.changeset(%{account_id: account.id, mode: account.credential_state})
               |> Repo.insert(),
             {:ok, _retention_setting} <-
               %RetentionSetting{}
               |> RetentionSetting.changeset(%{account_id: account.id})
               |> Repo.insert() do
          Repo.preload(account, [:credential, :retention_setting])
        else
          {:error, %Ecto.Changeset{} = changeset} -> Repo.rollback(changeset)
        end
      end)
    end
  end

  def verify_account_source(%Account{} = account) do
    attrs = %{
      "did" => account.did,
      "handle" => account.handle,
      "pinned_source_pds_url" => account.pinned_source_pds_url
    }

    with {:ok, verified_attrs} <- verified_registration_attrs(attrs),
         {:ok, account} <-
           account
           |> Account.verification_changeset(
             Map.take(verified_attrs, ["handle", "source_pds_url", "last_checked_at", "status", "status_reason"])
           )
           |> Repo.update() do
      {:ok, account}
    end
  end

  def verify_account_source(account_id) when is_integer(account_id),
    do: account_id |> get_account!() |> verify_account_source()

  def update_retention_setting(%Account{} = account, attrs) when is_map(attrs) do
    setting = account |> Repo.preload(:retention_setting, force: true) |> Map.fetch!(:retention_setting)

    setting
    |> RetentionSetting.changeset(Map.put(stringify_keys(attrs), "account_id", account.id))
    |> Repo.update()
  end

  def update_backup_schedule(%Account{} = account, attrs) when is_map(attrs) do
    attrs = stringify_keys(attrs)
    enabled? = truthy?(attrs["scheduled_backup_enabled"] || attrs["enabled"])
    interval_hours = parse_positive_integer(attrs["scheduled_backup_interval_hours"] || attrs["interval_hours"] || 24)
    now = DateTime.utc_now(:second)

    schedule_attrs = %{
      "scheduled_backup_enabled" => enabled?,
      "scheduled_backup_interval_hours" => interval_hours,
      "next_scheduled_backup_at" => if(enabled?, do: DateTime.add(now, interval_hours, :hour), else: nil)
    }

    account
    |> Account.schedule_changeset(schedule_attrs)
    |> Repo.update()
  end

  def pin_snapshot(%Snapshot{} = snapshot, pinned? \\ true) when is_boolean(pinned?) do
    snapshot
    |> Snapshot.pin_changeset(%{pinned: pinned?})
    |> Repo.update()
  end

  def prune_snapshots(%Account{} = account, opts \\ []) do
    config = Keyword.get(opts, :config, Tempest.Config.load!())
    account = Repo.preload(account, [:retention_setting, :snapshots], force: true)

    account.retention_setting
    |> snapshots_to_prune(account.snapshots, Keyword.get(opts, :now, DateTime.utc_now(:second)))
    |> Enum.reduce_while({:ok, []}, fn snapshot, {:ok, pruned} ->
      case delete_snapshot(snapshot, config) do
        :ok -> {:cont, {:ok, [snapshot | pruned]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, pruned} -> {:ok, Enum.reverse(pruned)}
      {:error, reason} -> {:error, reason}
    end
  end

  def export_snapshot_bundle(%Snapshot{} = snapshot, opts \\ []) do
    config = Keyword.get(opts, :config, Tempest.Config.load!())

    target_path =
      Keyword.get(opts, :path) || Path.join([config.data_dir, "tmp", Path.basename(snapshot.storage_key) <> ".zip"])

    Storage.archive_snapshot(config, snapshot.storage_key, target_path)
  end

  def run_manual_backup(%Account{} = account, opts \\ []) do
    with {:ok, locked_account, token} <- acquire_manual_backup_lock(account, opts),
         result <- create_repo_snapshot(locked_account, opts),
         :ok <- release_manual_backup_lock(locked_account, token) do
      result
    else
      {:error, :backup_already_running} = error ->
        error

      {:error, _reason} = error ->
        release_manual_backup_lock(account)
        error
    end
  end

  def run_due_scheduled_backups(opts \\ []) do
    now = Keyword.get(opts, :now, DateTime.utc_now(:second))

    due_account =
      Account
      |> where([account], account.scheduled_backup_enabled == true)
      |> where([account], is_nil(account.next_scheduled_backup_at) or account.next_scheduled_backup_at <= ^now)
      |> order_by([account], asc: account.next_scheduled_backup_at, asc: account.id)
      |> limit(1)
      |> Repo.one()

    case due_account do
      nil ->
        {:ok, :none_due}

      %Account{} = account ->
        with {:ok, result} <- run_manual_backup(account, Keyword.put(opts, :kind, "scheduled")),
             {:ok, updated_account} <- mark_schedule_ran(account, now) do
          {:ok, Map.put(result, :account, updated_account)}
        end
    end
  end

  def verify_snapshot_offline(snapshot_or_dir, opts \\ [])

  def verify_snapshot_offline(%Snapshot{} = snapshot, opts) do
    config = Keyword.get(opts, :config, Tempest.Config.load!())
    verify_snapshot_offline(Path.join(config.data_dir, snapshot.storage_key), opts)
  end

  def verify_snapshot_offline(snapshot_dir, _opts) when is_binary(snapshot_dir) do
    with {:ok, manifest} <- read_json_file(Path.join(snapshot_dir, "manifest.json")),
         {:ok, report} <- read_json_file(Path.join(snapshot_dir, "verification.json")),
         :ok <- verify_report_shape(report),
         :ok <- verify_repo_file(snapshot_dir, manifest),
         :ok <- verify_blob_files(snapshot_dir, manifest),
         :ok <- verify_preferences_file(snapshot_dir, manifest) do
      {:ok, %{status: "ok", manifest: manifest, report: report}}
    end
  end

  defp maybe_filter_snapshots_by_account(query, %Account{id: account_id}) do
    where(query, [snapshot], snapshot.account_id == ^account_id)
  end

  defp maybe_filter_snapshots_by_account(query, _account), do: query

  defp maybe_filter_snapshots_by_did(query, did) when is_binary(did) and did != "" do
    where(query, [snapshot], snapshot.did == ^did)
  end

  defp maybe_filter_snapshots_by_did(query, _did), do: query

  def create_repo_snapshot(%Account{} = account, opts \\ []) do
    config = Keyword.get(opts, :config, Tempest.Config.load!())

    Repo.transaction(fn ->
      with {:ok, verified_account} <- verify_account_source(account),
           {:ok, did_document} <- Identity.external_did_document_for_did(verified_account.did),
           {:ok, run} <- create_run(verified_account, Keyword.get(opts, :kind, "manual")),
           {:ok, repo_car} <- SourceClient.get_repo(verified_account.source_pds_url, verified_account.did, opts),
           {:ok, verified} <- Verifier.verify_repo_car(repo_car, did_document, verified_account.did),
           {:ok, workspace} <-
             prepare_snapshot_workspace(config, verified_account, did_document, verified, repo_car, opts),
           {:ok, snapshot_attrs} <- Storage.finalize_snapshot(config, workspace),
           {:ok, snapshot} <- insert_snapshot(verified_account, run, snapshot_attrs),
           {:ok, blobs} <- insert_blob_records(snapshot, workspace.blobs),
           {:ok, run} <- finish_run(run, snapshot),
           {:ok, account} <- mark_snapshot_success(verified_account, snapshot) do
        %{account: account, run: run, snapshot: %{snapshot | blobs: blobs}, verification: verified}
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp acquire_manual_backup_lock(%Account{} = account, opts) do
    now = DateTime.utc_now(:second)
    ttl_seconds = Keyword.get(opts, :lock_ttl_seconds, 60 * 60)
    token = Base.url_encode64(:crypto.strong_rand_bytes(18), padding: false)

    Repo.transaction(fn ->
      locked_account = Repo.get!(Account, account.id)

      if active_manual_lock?(locked_account, now) do
        Repo.rollback(:backup_already_running)
      else
        locked_account
        |> Account.lock_changeset(%{
          manual_lock_token: token,
          manual_lock_taken_at: now,
          manual_lock_expires_at: DateTime.add(now, ttl_seconds, :second)
        })
        |> Repo.update()
        |> case do
          {:ok, account} -> {account, token}
          {:error, %Ecto.Changeset{} = changeset} -> Repo.rollback(changeset)
        end
      end
    end)
    |> case do
      {:ok, {account, token}} -> {:ok, account, token}
      {:error, reason} -> {:error, reason}
    end
  end

  defp active_manual_lock?(%Account{manual_lock_token: token, manual_lock_expires_at: expires_at}, now)
       when is_binary(token) do
    match?(%DateTime{}, expires_at) and DateTime.compare(expires_at, now) == :gt
  end

  defp active_manual_lock?(_account, _now), do: false

  defp release_manual_backup_lock(%Account{} = account, token \\ nil) do
    case Repo.get(Account, account.id) do
      %Account{manual_lock_token: current_token} = account when is_nil(token) or current_token == token ->
        account
        |> Account.lock_changeset(%{manual_lock_token: nil, manual_lock_taken_at: nil, manual_lock_expires_at: nil})
        |> Repo.update()
        |> case do
          {:ok, _account} -> :ok
          {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset}
        end

      _account ->
        :ok
    end
  end

  defp mark_schedule_ran(%Account{} = account, now) do
    account = Repo.get!(Account, account.id)
    interval_hours = account.scheduled_backup_interval_hours || 24

    account
    |> Account.schedule_changeset(%{
      scheduled_backup_enabled: account.scheduled_backup_enabled,
      scheduled_backup_interval_hours: interval_hours,
      last_scheduled_backup_at: now,
      next_scheduled_backup_at: DateTime.add(now, interval_hours, :hour)
    })
    |> Repo.update()
  end

  defp verified_registration_attrs(attrs) do
    now = DateTime.utc_now(:second)
    did = attrs["did"] |> trim_string()
    handle = attrs["handle"] |> normalize_handle()
    pinned_source = normalize_url(attrs["pinned_source_pds_url"] || attrs["pinnedSourcePdsUrl"])

    with :ok <- Identity.validate_did_syntax(did),
         :ok <- Identity.validate_handle_syntax(handle),
         {:ok, ^did} <- Identity.resolve_handle(handle),
         {:ok, document} <- Identity.external_did_document_for_did(did),
         true <- DidDocument.claims_handle?(document, handle),
         {:ok, source_pds_url} <- source_pds_url(document),
         :ok <- verify_pinned_source(source_pds_url, pinned_source) do
      {:ok,
       attrs
       |> Map.put("did", did)
       |> Map.put("handle", handle)
       |> Map.put("label", label_for(attrs, handle))
       |> Map.put("source_pds_url", source_pds_url)
       |> Map.put("pinned_source_pds_url", pinned_source)
       |> Map.put("credential_state", credential_state(attrs))
       |> Map.put("last_checked_at", now)
       |> Map.put("status", "verified")
       |> Map.put("status_reason", nil)}
    else
      {:ok, _other_did} -> {:error, :handle_did_mismatch}
      false -> {:error, :did_document_handle_mismatch}
      {:error, reason} -> {:error, reason}
    end
  end

  defp source_pds_url(%{"service" => services}) when is_list(services) do
    services
    |> Enum.find(&atproto_pds_service?/1)
    |> case do
      %{"serviceEndpoint" => endpoint} when is_binary(endpoint) ->
        endpoint
        |> normalize_url()
        |> validate_origin_url()

      _service ->
        {:error, :missing_atproto_pds}
    end
  end

  defp source_pds_url(_document), do: {:error, :missing_atproto_pds}

  defp atproto_pds_service?(%{"id" => "#atproto_pds", "type" => "AtprotoPersonalDataServer"}), do: true
  defp atproto_pds_service?(_service), do: false

  defp verify_pinned_source(_source_pds_url, nil), do: :ok

  defp verify_pinned_source(source_pds_url, pinned_source) do
    if source_pds_url == pinned_source do
      :ok
    else
      {:error, :pinned_source_pds_mismatch}
    end
  end

  defp validate_origin_url(nil), do: {:error, :invalid_source_pds_url}

  defp validate_origin_url(url) do
    uri = URI.parse(url)

    if uri.scheme in ["http", "https"] and is_binary(uri.host) and uri.host != "" and
         uri.path in [nil, ""] and is_nil(uri.query) and is_nil(uri.fragment) do
      {:ok, url}
    else
      {:error, :invalid_source_pds_url}
    end
  end

  defp credential_attrs("none", _secret) do
    {:ok,
     %{
       mode: "none",
       secret_ciphertext: nil,
       secret_hint: nil,
       verified_at: nil,
       deleted_at: DateTime.utc_now(:second)
     }}
  end

  defp credential_attrs(mode, secret) when mode in ["app_password", "access_token"] do
    with {:ok, ciphertext} <- SecretStore.encrypt(secret) do
      {:ok,
       %{
         mode: mode,
         secret_ciphertext: ciphertext,
         secret_hint: SecretStore.hint(secret),
         verified_at: nil,
         deleted_at: nil
       }}
    end
  end

  defp update_account_credential_state(%Account{} = account, mode) do
    account
    |> Account.registration_changeset(%{
      label: account.label,
      did: account.did,
      handle: account.handle,
      source_pds_url: account.source_pds_url,
      pinned_source_pds_url: account.pinned_source_pds_url,
      credential_state: mode,
      last_checked_at: account.last_checked_at,
      last_success_at: account.last_success_at,
      last_snapshot_id: account.last_snapshot_id,
      status: account.status,
      status_reason: account.status_reason
    })
    |> Repo.update()
  end

  defp truthy?(value) when value in [true, "true", "1", "on", "yes"], do: true
  defp truthy?(_value), do: false

  defp parse_positive_integer(value) when is_integer(value) and value >= 1, do: value

  defp parse_positive_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int >= 1 -> int
      _invalid -> 24
    end
  end

  defp parse_positive_integer(_value), do: 24

  defp create_run(%Account{} = account, kind) when kind in ["manual", "scheduled"] do
    %Run{}
    |> Run.changeset(%{
      account_id: account.id,
      status: "running",
      kind: kind,
      started_at: DateTime.utc_now(:second),
      metadata: %{}
    })
    |> Repo.insert()
  end

  defp finish_run(%Run{} = run, %Snapshot{} = snapshot) do
    run
    |> Run.changeset(%{
      snapshot_id: snapshot.id,
      status: "succeeded",
      kind: run.kind,
      started_at: run.started_at,
      finished_at: DateTime.utc_now(:second),
      metadata: run.metadata
    })
    |> Repo.update()
  end

  defp mark_snapshot_success(%Account{} = account, %Snapshot{} = snapshot) do
    account
    |> Account.registration_changeset(%{
      label: account.label,
      did: account.did,
      handle: snapshot.handle,
      source_pds_url: snapshot.source_pds_url,
      pinned_source_pds_url: account.pinned_source_pds_url,
      credential_state: account.credential_state,
      last_checked_at: account.last_checked_at,
      last_success_at: DateTime.utc_now(:second),
      last_snapshot_id: snapshot.id,
      status: "verified",
      status_reason: nil
    })
    |> Repo.update()
  end

  defp snapshots_to_prune(%RetentionSetting{policy: "keep_all"}, _snapshots, _now), do: []

  defp snapshots_to_prune(%RetentionSetting{policy: "keep_last_n", keep_last: keep_last}, snapshots, _now) do
    snapshots
    |> Enum.reject(& &1.pinned)
    |> Enum.sort_by(&snapshot_sort_key/1, :desc)
    |> Enum.drop(keep_last)
  end

  defp snapshots_to_prune(%RetentionSetting{policy: "keep_for_days", keep_days: keep_days}, snapshots, now)
       when is_integer(keep_days) do
    cutoff = DateTime.add(now, -keep_days, :day)

    snapshots
    |> Enum.reject(& &1.pinned)
    |> Enum.filter(fn snapshot ->
      case snapshot.completed_at || snapshot.inserted_at do
        %DateTime{} = completed_at -> DateTime.compare(completed_at, cutoff) == :lt
        _missing -> false
      end
    end)
  end

  defp snapshots_to_prune(_setting, _snapshots, _now), do: []

  defp snapshot_sort_key(snapshot), do: snapshot.completed_at || snapshot.inserted_at || ~U[1970-01-01 00:00:00Z]

  defp delete_snapshot(%Snapshot{} = snapshot, config) do
    Repo.transaction(fn ->
      with {:ok, _snapshot} <- Repo.delete(snapshot),
           :ok <- Storage.delete_snapshot(config, snapshot.storage_key),
           :ok <- maybe_clear_last_snapshot(snapshot) do
        :ok
      else
        {:error, %Ecto.Changeset{} = changeset} -> Repo.rollback(changeset)
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> case do
      {:ok, :ok} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp maybe_clear_last_snapshot(%Snapshot{} = snapshot) do
    case Repo.get(Account, snapshot.account_id) do
      %Account{last_snapshot_id: id} = account when id == snapshot.id ->
        account
        |> Account.registration_changeset(%{
          label: account.label,
          did: account.did,
          handle: account.handle,
          source_pds_url: account.source_pds_url,
          pinned_source_pds_url: account.pinned_source_pds_url,
          credential_state: account.credential_state,
          last_checked_at: account.last_checked_at,
          last_success_at: account.last_success_at,
          last_snapshot_id: nil,
          status: account.status,
          status_reason: account.status_reason
        })
        |> Repo.update()
        |> case do
          {:ok, _account} -> :ok
          {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset}
        end

      _account ->
        :ok
    end
  end

  defp read_json_file(path) do
    with {:ok, bytes} <- File.read(path),
         {:ok, json} <- Jason.decode(bytes) do
      {:ok, json}
    else
      {:error, reason} -> {:error, {:invalid_json_file, path, reason}}
    end
  end

  defp verify_report_shape(%{"status" => status, "checked_at" => checked_at})
       when status in ["ok", "warning"] and is_binary(checked_at),
       do: :ok

  defp verify_report_shape(%{"status" => status, "checkedAt" => checked_at})
       when status in ["ok", "warning"] and is_binary(checked_at),
       do: :ok

  defp verify_report_shape(_report), do: {:error, :invalid_verification_report}

  defp verify_repo_file(snapshot_dir, manifest) do
    with %{"account" => %{"did" => did}, "repo" => repo, "identity" => %{"didDocument" => did_document}} <- manifest,
         repo_path = Path.join(snapshot_dir, Map.fetch!(repo, "carPath")),
         {:ok, bytes} <- File.read(repo_path),
         :ok <- verify_file_hash(bytes, Map.fetch!(repo, "sha256")),
         true <- byte_size(bytes) == Map.fetch!(repo, "byteSize"),
         {:ok, verified} <- Verifier.verify_repo_car(bytes, did_document, did),
         true <- verified.commit_cid_string == Map.fetch!(repo, "commit"),
         true <- verified.rev == Map.fetch!(repo, "rev") do
      :ok
    else
      false -> {:error, :repo_manifest_mismatch}
      {:error, reason} -> {:error, reason}
      _match -> {:error, :invalid_manifest_repo}
    end
  end

  defp verify_blob_files(snapshot_dir, %{"blobFiles" => blob_files}) when is_list(blob_files) do
    Enum.reduce_while(blob_files, :ok, fn blob, :ok ->
      case verify_blob_file(snapshot_dir, blob) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp verify_blob_files(_snapshot_dir, _manifest), do: {:error, :invalid_manifest_blobs}

  defp verify_blob_file(_snapshot_dir, %{"status" => status}) when status in ["missing", "failed"], do: :ok

  defp verify_blob_file(snapshot_dir, %{
         "cid" => cid,
         "path" => path,
         "byteSize" => byte_size,
         "sha256" => hash,
         "status" => "stored"
       }) do
    with {:ok, bytes} <- File.read(Path.join(snapshot_dir, path)),
         :ok <- verify_file_hash(bytes, hash),
         true <- byte_size(bytes) == byte_size,
         {:ok, expected_cid} <- Cid.parse(cid),
         true <- Cid.for_raw(bytes) == expected_cid do
      :ok
    else
      false -> {:error, {:blob_manifest_mismatch, cid}}
      {:error, reason} -> {:error, {:blob_verify_failed, cid, reason}}
    end
  end

  defp verify_blob_file(_snapshot_dir, _blob), do: {:error, :invalid_manifest_blob}

  defp verify_preferences_file(_snapshot_dir, %{"preferences" => %{"included" => false}}), do: :ok

  defp verify_preferences_file(snapshot_dir, %{"preferences" => %{"included" => true, "path" => path}}) do
    with {:ok, _preferences} <- read_json_file(Path.join(snapshot_dir, path)), do: :ok
  end

  defp verify_preferences_file(_snapshot_dir, _manifest), do: {:error, :invalid_manifest_preferences}

  defp verify_file_hash(bytes, expected_hash) when is_binary(expected_hash) do
    if sha256(bytes) == expected_hash, do: :ok, else: {:error, :sha256_mismatch}
  end

  defp verify_file_hash(_bytes, _hash), do: {:error, :missing_sha256}

  defp prepare_snapshot_workspace(config, %Account{} = account, did_document, verified, repo_car, opts) do
    storage_key = snapshot_storage_key(account.did, verified.rev)
    temp_dir = snapshot_temp_dir(config)
    final_dir = Path.join(config.data_dir, storage_key)
    repo_car_path = Path.join(temp_dir, "repo.car")

    with :ok <- File.mkdir_p(temp_dir),
         :ok <- File.write(repo_car_path, repo_car),
         {:ok, blob_cids} <- snapshot_blob_cids(account, verified, opts),
         {:ok, blob_results} <- download_snapshot_blobs(account, temp_dir, blob_cids, opts),
         {:ok, preferences} <- maybe_write_preferences(account, temp_dir, opts),
         report = verification_report(account, verified, blob_results, preferences),
         manifest = snapshot_manifest(account, did_document, verified, repo_car, blob_results, preferences, report),
         :ok <- File.write(Path.join(temp_dir, "verification.json"), Jason.encode!(report, pretty: true)),
         :ok <- File.write(Path.join(temp_dir, "manifest.json"), Jason.encode!(manifest, pretty: true)) do
      {:ok,
       %{
         account: account,
         storage_key: storage_key,
         temp_dir: temp_dir,
         final_dir: final_dir,
         repo_car_path: Path.join(storage_key, "repo.car"),
         manifest_path: Path.join(storage_key, "manifest.json"),
         verification_report_path: Path.join(storage_key, "verification.json"),
         commit_cid: verified.commit_cid_string,
         rev: verified.rev,
         source_pds_url: account.source_pds_url,
         handle: account.handle,
         did: account.did,
         byte_size: byte_size(repo_car),
         sha256: sha256(repo_car),
         status: snapshot_status(blob_results),
         verification_status: snapshot_verification_status(blob_results, preferences),
         blobs: blob_results,
         preferences: preferences
       }}
    end
  end

  defp insert_snapshot(%Account{} = account, %Run{} = run, attrs) do
    %Snapshot{}
    |> Snapshot.changeset(
      Map.merge(attrs, %{
        account_id: account.id,
        run_id: run.id,
        status: attrs.status,
        completed_at: DateTime.utc_now(:second),
        manifest_path: attrs.manifest_path,
        verification_status: attrs.verification_status,
        verification_report_path: attrs.verification_report_path
      })
    )
    |> Repo.insert()
  end

  defp insert_blob_records(%Snapshot{} = snapshot, blobs) do
    Enum.reduce_while(blobs, {:ok, []}, fn blob, {:ok, inserted} ->
      attrs =
        blob
        |> Map.take([:cid, :path, :byte_size, :sha256, :status, :error_reason])
        |> Map.put(:snapshot_id, snapshot.id)

      case %Tempest.PersonalBackups.Blob{} |> Tempest.PersonalBackups.Blob.changeset(attrs) |> Repo.insert() do
        {:ok, row} -> {:cont, {:ok, [row | inserted]}}
        {:error, %Ecto.Changeset{} = changeset} -> {:halt, {:error, changeset}}
      end
    end)
    |> case do
      {:ok, rows} -> {:ok, Enum.reverse(rows)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp snapshot_storage_key(did, rev) do
    stamp = DateTime.utc_now(:second) |> DateTime.to_iso8601(:basic) |> String.replace(~r/[^0-9A-Za-z]/, "")
    safe_did = String.replace(did, ~r/[^A-Za-z0-9._-]/, "_")
    safe_rev = String.replace(rev, ~r/[^A-Za-z0-9._-]/, "_")
    suffix = System.unique_integer([:positive])
    Path.join(["personal-backups", safe_did, "snapshots", stamp <> "-" <> safe_rev <> "-" <> Integer.to_string(suffix)])
  end

  defp snapshot_temp_dir(config) do
    Path.join([config.data_dir, "tmp", "personal-backups", Integer.to_string(System.unique_integer([:positive]))])
  end

  defp snapshot_blob_cids(account, verified, opts) do
    with {:ok, listed_cids} <- list_all_source_blob_cids(account, opts),
         referenced_cids = referenced_blob_cids(verified) do
      {:ok, Enum.sort(Enum.uniq(referenced_cids ++ listed_cids))}
    end
  end

  defp list_all_source_blob_cids(account, opts, cursor \\ nil, cids \\ []) do
    request_opts =
      opts
      |> Keyword.put(:limit, Keyword.get(opts, :blob_page_limit, 500))
      |> maybe_put_keyword(:cursor, cursor)

    with {:ok, response} <- SourceClient.list_blobs(account.source_pds_url, account.did, request_opts),
         page_cids <- Map.get(response, "cids", Map.get(response, "blobs", [])),
         :ok <- validate_cid_list(page_cids) do
      case Map.get(response, "cursor") do
        next_cursor when is_binary(next_cursor) and next_cursor != "" ->
          list_all_source_blob_cids(account, opts, next_cursor, cids ++ page_cids)

        _cursor ->
          {:ok, cids ++ page_cids}
      end
    end
  end

  defp validate_cid_list(cids) when is_list(cids) do
    Enum.reduce_while(cids, :ok, fn
      cid, :ok when is_binary(cid) ->
        case Cid.parse(cid) do
          {:ok, _cid} -> {:cont, :ok}
          {:error, reason} -> {:halt, {:error, {:invalid_blob_cid, cid, reason}}}
        end

      _cid, :ok ->
        {:halt, {:error, :invalid_blob_list}}
    end)
  end

  defp validate_cid_list(_cids), do: {:error, :invalid_blob_list}

  defp referenced_blob_cids(verified) do
    blocks = Map.new(verified.car.blocks, fn %{cid: cid, data: data} -> {Cid.to_string(cid), data} end)

    verified.entries
    |> Map.values()
    |> Enum.flat_map(fn cid ->
      cid
      |> Cid.to_string()
      |> then(&Map.get(blocks, &1))
      |> decode_record_block()
      |> extract_blob_cids()
    end)
    |> Enum.uniq()
  end

  defp decode_record_block(nil), do: nil

  defp decode_record_block(bytes) do
    case Drisl.decode(bytes) do
      {:ok, value} -> value
      {:error, _reason} -> Jason.decode(bytes) |> elem_or_nil()
    end
  end

  defp elem_or_nil({:ok, value}), do: value
  defp elem_or_nil({:error, _reason}), do: nil

  defp extract_blob_cids(%{"$type" => "blob", "ref" => %{"$link" => cid}}) when is_binary(cid), do: [cid]
  defp extract_blob_cids(%{"$type" => "blob", "cid" => cid}) when is_binary(cid), do: [cid]

  defp extract_blob_cids(map) when is_map(map) do
    map
    |> Map.values()
    |> Enum.flat_map(&extract_blob_cids/1)
  end

  defp extract_blob_cids(list) when is_list(list), do: Enum.flat_map(list, &extract_blob_cids/1)
  defp extract_blob_cids(_value), do: []

  defp download_snapshot_blobs(account, temp_dir, cids, opts) do
    blob_dir = Path.join(temp_dir, "blobs")

    with :ok <- File.mkdir_p(blob_dir) do
      cids
      |> Task.async_stream(
        fn cid -> download_snapshot_blob(account, blob_dir, cid, opts) end,
        max_concurrency: Keyword.get(opts, :blob_concurrency, @default_blob_concurrency),
        timeout: :infinity
      )
      |> Enum.reduce_while({:ok, []}, fn
        {:ok, blob}, {:ok, blobs} -> {:cont, {:ok, [blob | blobs]}}
        {:exit, reason}, {:ok, _blobs} -> {:halt, {:error, {:blob_task_exit, reason}}}
      end)
      |> case do
        {:ok, blobs} -> {:ok, Enum.reverse(blobs)}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp download_snapshot_blob(account, blob_dir, cid, opts) do
    case fetch_blob_with_retry(account, cid, opts, @transient_retries) do
      {:ok, bytes} ->
        verify_and_write_blob(blob_dir, cid, bytes)

      {:error, {:source_pds_http_error, status}} when status in [404, 410] ->
        %{cid: cid, path: nil, byte_size: 0, sha256: nil, status: "missing", error_reason: "source returned #{status}"}

      {:error, reason} ->
        %{cid: cid, path: nil, byte_size: 0, sha256: nil, status: "failed", error_reason: inspect(reason)}
    end
  end

  defp fetch_blob_with_retry(account, cid, opts, retries_left) do
    case SourceClient.get_blob(account.source_pds_url, account.did, cid, opts) do
      {:error, reason} ->
        if retries_left > 0 and transient_blob_error?(reason) do
          fetch_blob_with_retry(account, cid, opts, retries_left - 1)
        else
          {:error, reason}
        end

      result ->
        result
    end
  end

  defp transient_blob_error?({:source_pds_http_error, status}) when status in 500..599, do: true
  defp transient_blob_error?({:source_pds_request_failed, _reason}), do: true
  defp transient_blob_error?(_reason), do: false

  defp verify_and_write_blob(blob_dir, cid, bytes) do
    with {:ok, expected_cid} <- Cid.parse(cid),
         actual_cid = Cid.for_raw(bytes),
         true <- actual_cid == expected_cid,
         path = Path.join(blob_dir, cid),
         :ok <- File.write(path, bytes) do
      %{
        cid: cid,
        path: Path.join(["blobs", cid]),
        byte_size: byte_size(bytes),
        sha256: sha256(bytes),
        status: "stored",
        error_reason: nil
      }
    else
      false ->
        %{cid: cid, path: nil, byte_size: 0, sha256: nil, status: "failed", error_reason: "cid_mismatch"}

      {:error, reason} ->
        %{cid: cid, path: nil, byte_size: 0, sha256: nil, status: "failed", error_reason: inspect(reason)}
    end
  end

  defp maybe_write_preferences(account, temp_dir, opts) do
    with {:ok, credential} <- preferences_credential(account),
         {:ok, secret} <- SecretStore.decrypt(credential.secret_ciphertext),
         {:ok, preferences} <- SourceClient.get_preferences(account.source_pds_url, secret, opts),
         :ok <- File.write(Path.join(temp_dir, "preferences.json"), Jason.encode!(preferences, pretty: true)) do
      {:ok, %{included: true, path: "preferences.json", warning: nil}}
    else
      {:skip, reason} when reason in [:no_credentials, :credential_deleted] ->
        {:ok, %{included: false, path: nil, warning: nil}}

      {:skip, reason} ->
        {:ok, %{included: false, path: nil, warning: Atom.to_string(reason)}}

      {:error, reason} ->
        {:ok, %{included: false, path: nil, warning: "preferences_auth_or_fetch_failed: #{inspect(reason)}"}}
    end
  end

  defp preferences_credential(account) do
    credential = account |> Repo.preload(:credential, force: true) |> Map.fetch!(:credential)

    case credential do
      %Credential{mode: "none"} -> {:skip, :no_credentials}
      %Credential{deleted_at: %DateTime{}} -> {:skip, :credential_deleted}
      %Credential{secret_ciphertext: secret} when is_binary(secret) and secret != "" -> {:ok, credential}
      %Credential{} -> {:skip, :credential_missing_secret}
    end
  end

  defp snapshot_manifest(account, did_document, verified, repo_car, blobs, preferences, report) do
    missing = blobs |> Enum.filter(&(&1.status == "missing")) |> Enum.map(& &1.cid)

    %{
      "version" => 1,
      "account" => %{
        "did" => account.did,
        "handle" => account.handle,
        "sourcePds" => account.source_pds_url
      },
      "identity" => %{
        "didDocument" => did_document
      },
      "repo" => %{
        "carPath" => "repo.car",
        "commit" => verified.commit_cid_string,
        "rev" => verified.rev,
        "byteSize" => byte_size(repo_car),
        "sha256" => sha256(repo_car)
      },
      "blobs" => %{
        "count" => Enum.count(blobs, &(&1.status == "stored")),
        "expected" => length(blobs),
        "complete" => Enum.all?(blobs, &(&1.status == "stored")),
        "missing" => missing
      },
      "blobFiles" => Enum.map(blobs, &blob_manifest_entry/1),
      "preferences" => Map.take(preferences, [:included, :path]) |> stringify_map_keys(),
      "verification" => %{
        "status" => report.status,
        "checkedAt" => report.checked_at,
        "path" => "verification.json"
      }
    }
  end

  defp blob_manifest_entry(blob) do
    %{
      "cid" => blob.cid,
      "path" => blob.path,
      "byteSize" => blob.byte_size,
      "sha256" => blob.sha256,
      "status" => blob.status,
      "errorReason" => blob.error_reason
    }
  end

  defp verification_report(account, verified, blobs, preferences) do
    warnings =
      []
      |> add_warning(preferences.warning)
      |> add_warning_if(Enum.any?(blobs, &(&1.status == "missing")), "missing_blobs")
      |> add_warning_if(Enum.any?(blobs, &(&1.status == "failed")), "failed_blobs")

    %{
      status: if(warnings == [], do: "ok", else: "warning"),
      checked_at: DateTime.utc_now(:second) |> DateTime.to_iso8601(),
      did: account.did,
      handle: account.handle,
      source_pds_url: account.source_pds_url,
      commit_cid: verified.commit_cid_string,
      rev: verified.rev,
      record_count: verified.record_count,
      blob_count: length(blobs),
      stored_blob_count: Enum.count(blobs, &(&1.status == "stored")),
      warnings: Enum.reverse(warnings)
    }
  end

  defp snapshot_status(blobs) do
    if Enum.all?(blobs, &(&1.status == "stored")), do: "complete", else: "incomplete"
  end

  defp snapshot_verification_status(blobs, preferences) do
    if snapshot_status(blobs) == "complete" and is_nil(preferences.warning), do: "ok", else: "warning"
  end

  defp add_warning(warnings, nil), do: warnings
  defp add_warning(warnings, warning), do: [warning | warnings]

  defp add_warning_if(warnings, true, warning), do: [warning | warnings]
  defp add_warning_if(warnings, false, _warning), do: warnings

  defp stringify_map_keys(map) do
    Map.new(map, fn {key, value} -> {Atom.to_string(key), value} end)
  end

  defp maybe_put_keyword(keyword, _key, nil), do: keyword
  defp maybe_put_keyword(keyword, key, value), do: Keyword.put(keyword, key, value)

  defp sha256(bytes), do: :sha256 |> :crypto.hash(bytes) |> Base.encode16(case: :lower)

  defp stringify_keys(attrs) do
    Map.new(attrs, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} -> {key, value}
    end)
  end

  defp label_for(attrs, handle) do
    case trim_string(attrs["label"]) do
      nil -> handle
      label -> label
    end
  end

  defp credential_state(attrs) do
    case attrs["credential_state"] || attrs["credentialState"] do
      state when state in ["none", "app_password", "access_token"] -> state
      _other -> "none"
    end
  end

  defp normalize_handle(handle) when is_binary(handle), do: Tempest.Identity.Validators.normalize_handle(handle)
  defp normalize_handle(handle), do: handle

  defp normalize_url(url) when is_binary(url) do
    url
    |> String.trim()
    |> String.trim_trailing("/")
    |> blank_to_nil()
  end

  defp normalize_url(url), do: url

  defp trim_string(value) when is_binary(value), do: value |> String.trim() |> blank_to_nil()
  defp trim_string(value), do: value

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
