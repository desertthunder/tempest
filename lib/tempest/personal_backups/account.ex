defmodule Tempest.PersonalBackups.Account do
  @moduledoc """
  External AT Protocol account registered for admin-managed personal backups.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Tempest.Identity.Validators
  alias Tempest.PersonalBackups.{Credential, RetentionSetting, Run, Snapshot}

  @credential_states ~w(none app_password access_token)
  @statuses ~w(pending verified warning failed disabled)

  schema "personal_backup_accounts" do
    field :label, :string
    field :did, :string
    field :handle, :string
    field :source_pds_url, :string
    field :pinned_source_pds_url, :string
    field :credential_state, :string, default: "none"
    field :last_checked_at, :utc_datetime
    field :last_success_at, :utc_datetime
    field :last_snapshot_id, :integer
    field :status, :string, default: "pending"
    field :status_reason, :string

    has_one :credential, Credential
    has_one :retention_setting, RetentionSetting
    has_many :runs, Run
    has_many :snapshots, Snapshot

    timestamps(type: :utc_datetime)
  end

  def registration_changeset(account, attrs) do
    account
    |> cast(attrs, [
      :label,
      :did,
      :handle,
      :source_pds_url,
      :pinned_source_pds_url,
      :credential_state,
      :last_checked_at,
      :last_success_at,
      :last_snapshot_id,
      :status,
      :status_reason
    ])
    |> normalize_fields()
    |> validate_required([:label, :did, :handle, :source_pds_url, :credential_state, :status])
    |> validate_length(:label, min: 1, max: 120)
    |> validate_length(:status_reason, max: 500)
    |> validate_identity_did()
    |> validate_identity_handle()
    |> validate_pds_url(:source_pds_url)
    |> validate_pds_url(:pinned_source_pds_url)
    |> validate_inclusion(:credential_state, @credential_states)
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint(:did)
  end

  def verification_changeset(account, attrs) do
    account
    |> cast(attrs, [:handle, :source_pds_url, :last_checked_at, :status, :status_reason])
    |> normalize_fields()
    |> validate_required([:handle, :source_pds_url, :last_checked_at, :status])
    |> validate_identity_handle()
    |> validate_pds_url(:source_pds_url)
    |> validate_inclusion(:status, @statuses)
  end

  defp normalize_fields(changeset) do
    changeset
    |> update_change(:label, &trim_or_nil/1)
    |> update_change(:did, &trim_or_nil/1)
    |> update_change(:handle, &normalize_handle/1)
    |> update_change(:source_pds_url, &normalize_url/1)
    |> update_change(:pinned_source_pds_url, &normalize_url/1)
    |> update_change(:status_reason, &trim_or_nil/1)
  end

  defp normalize_handle(handle) when is_binary(handle), do: Validators.normalize_handle(handle)
  defp normalize_handle(handle), do: handle

  defp normalize_url(url) when is_binary(url) do
    url
    |> String.trim()
    |> String.trim_trailing("/")
    |> blank_to_nil()
  end

  defp normalize_url(url), do: url

  defp trim_or_nil(value) when is_binary(value), do: value |> String.trim() |> blank_to_nil()
  defp trim_or_nil(value), do: value

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp validate_identity_did(changeset) do
    validate_change(changeset, :did, fn :did, did ->
      case Validators.validate_did(did) do
        :ok -> []
        {:error, :unsupported_did_method} -> [did: "uses an unsupported DID method"]
        {:error, :invalid_did_syntax} -> [did: "has invalid syntax"]
      end
    end)
  end

  defp validate_identity_handle(changeset) do
    validate_change(changeset, :handle, fn :handle, handle ->
      case Validators.validate_handle(handle) do
        :ok -> []
        {:error, :invalid_handle_syntax} -> [handle: "has invalid syntax"]
      end
    end)
  end

  defp validate_pds_url(changeset, field) do
    validate_change(changeset, field, fn ^field, url ->
      uri = URI.parse(url)

      if uri.scheme in ["http", "https"] and is_binary(uri.host) and uri.host != "" and
           uri.path in [nil, ""] and is_nil(uri.query) and is_nil(uri.fragment) do
        []
      else
        [{field, "must be an http or https origin URL"}]
      end
    end)
  end
end
