defmodule Tempest.PersonalBackups.RetentionSetting do
  @moduledoc """
  Per-account personal backup retention policy.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Tempest.PersonalBackups.Account

  @policies ~w(keep_all keep_last_n keep_for_days)

  schema "personal_backup_retention_settings" do
    field :policy, :string, default: "keep_last_n"
    field :keep_last, :integer, default: 3
    field :keep_days, :integer

    belongs_to :account, Account

    timestamps(type: :utc_datetime)
  end

  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [:account_id, :policy, :keep_last, :keep_days])
    |> validate_required([:account_id, :policy, :keep_last])
    |> validate_inclusion(:policy, @policies)
    |> validate_number(:keep_last, greater_than: 0)
    |> validate_keep_days()
    |> unique_constraint(:account_id)
  end

  defp validate_keep_days(changeset) do
    if get_field(changeset, :policy) == "keep_for_days" do
      changeset
      |> validate_required([:keep_days])
      |> validate_number(:keep_days, greater_than: 0)
    else
      changeset
    end
  end
end
