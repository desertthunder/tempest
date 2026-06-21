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
    Verifier
  }

  alias Tempest.Repo

  def list_accounts do
    Account
    |> order_by([account], asc: account.handle)
    |> Repo.all()
  end

  def get_account!(id), do: Repo.get!(Account, id)
  def get_account_by_did(did) when is_binary(did), do: Repo.get_by(Account, did: did)

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

  def create_repo_snapshot(%Account{} = account, opts \\ []) do
    config = Keyword.get(opts, :config, Tempest.Config.load!())

    Repo.transaction(fn ->
      with {:ok, verified_account} <- verify_account_source(account),
           {:ok, did_document} <- Identity.external_did_document_for_did(verified_account.did),
           {:ok, run} <- create_run(verified_account),
           {:ok, repo_car} <- SourceClient.get_repo(verified_account.source_pds_url, verified_account.did, opts),
           {:ok, verified} <- Verifier.verify_repo_car(repo_car, did_document, verified_account.did),
           {:ok, snapshot_attrs} <- write_repo_snapshot(config, verified_account, verified, repo_car),
           {:ok, snapshot} <- insert_snapshot(verified_account, run, snapshot_attrs),
           {:ok, run} <- finish_run(run, snapshot),
           {:ok, account} <- mark_snapshot_success(verified_account, snapshot) do
        %{account: account, run: run, snapshot: snapshot, verification: verified}
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
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

  defp create_run(%Account{} = account) do
    %Run{}
    |> Run.changeset(%{
      account_id: account.id,
      status: "running",
      kind: "manual",
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

  defp write_repo_snapshot(config, %Account{} = account, verified, repo_car) do
    storage_key = snapshot_storage_key(account.did, verified.rev)
    snapshot_dir = Path.join(config.data_dir, storage_key)
    repo_car_path = Path.join(snapshot_dir, "repo.car")

    with :ok <- File.mkdir_p(snapshot_dir),
         :ok <- File.write(repo_car_path, repo_car) do
      {:ok,
       %{
         storage_key: storage_key,
         repo_car_path: Path.join(storage_key, "repo.car"),
         commit_cid: verified.commit_cid_string,
         rev: verified.rev,
         source_pds_url: account.source_pds_url,
         handle: account.handle,
         did: account.did,
         byte_size: byte_size(repo_car),
         sha256: sha256(repo_car)
       }}
    end
  end

  defp insert_snapshot(%Account{} = account, %Run{} = run, attrs) do
    %Snapshot{}
    |> Snapshot.changeset(
      Map.merge(attrs, %{
        account_id: account.id,
        run_id: run.id,
        status: "complete",
        completed_at: DateTime.utc_now(:second),
        verification_status: "ok"
      })
    )
    |> Repo.insert()
  end

  defp snapshot_storage_key(did, rev) do
    stamp = DateTime.utc_now(:second) |> DateTime.to_iso8601(:basic) |> String.replace(~r/[^0-9A-Za-z]/, "")
    safe_did = String.replace(did, ~r/[^A-Za-z0-9._-]/, "_")
    safe_rev = String.replace(rev, ~r/[^A-Za-z0-9._-]/, "_")
    Path.join(["personal-backups", safe_did, "snapshots", stamp <> "-" <> safe_rev])
  end

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
