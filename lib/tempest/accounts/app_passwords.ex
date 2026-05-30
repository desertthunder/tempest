defmodule Tempest.Accounts.AppPasswords do
  @moduledoc """
  App password creation, listing, revocation, and authentication.
  """

  import Ecto.Query

  alias Tempest.Accounts.{Account, AppPassword}
  alias Tempest.Repo

  @prefix "tempest-app-password-v1."
  @default_scope "atproto"

  def create(%Account{} = account, attrs) when is_map(attrs) do
    name = Map.get(attrs, "name") || Map.get(attrs, :name)
    scope = Map.get(attrs, "scope") || Map.get(attrs, :scope) || @default_scope

    with :ok <- validate_scope(scope) do
      secret = @prefix <> random_token(32)

      %AppPassword{}
      |> AppPassword.changeset(%{
        account_id: account.id,
        name: name,
        scope: scope,
        token_hash: hash(secret)
      })
      |> Repo.insert()
      |> case do
        {:ok, app_password} -> {:ok, Map.put(public(app_password), "password", secret)}
        {:error, changeset} -> {:error, changeset}
      end
    end
  end

  def list(%Account{} = account) do
    AppPassword
    |> where([p], p.account_id == ^account.id)
    |> order_by([p], desc: p.inserted_at)
    |> Repo.all()
    |> Enum.map(&public/1)
  end

  def revoke(%Account{} = account, id) do
    now = now()

    AppPassword
    |> where([p], p.account_id == ^account.id and p.id == ^id and is_nil(p.revoked_at))
    |> Repo.update_all(set: [revoked_at: now])
    |> case do
      {1, _rows} -> :ok
      _other -> {:error, :not_found}
    end
  end

  def authenticate(secret) when is_binary(secret) do
    app_password =
      AppPassword
      |> where([p], p.token_hash == ^hash(secret))
      |> where([p], is_nil(p.revoked_at))
      |> preload(:account)
      |> Repo.one()

    cond do
      is_nil(app_password) ->
        {:error, :invalid_token}

      not app_password.account.active or app_password.account.status != "active" ->
        {:error, :inactive_account}

      true ->
        app_password
        |> AppPassword.changeset(%{last_used_at: now()})
        |> Repo.update()

        {:ok, app_password.account, app_password}
    end
  end

  def authenticate(_secret), do: {:error, :invalid_token}

  defp public(%AppPassword{} = app_password) do
    %{
      "id" => app_password.id,
      "name" => app_password.name,
      "scope" => app_password.scope,
      "createdAt" => DateTime.to_iso8601(app_password.inserted_at),
      "revoked" => not is_nil(app_password.revoked_at),
      "lastUsedAt" => iso8601_or_nil(app_password.last_used_at)
    }
  end

  defp validate_scope(scope) when is_binary(scope) and scope != "", do: :ok
  defp validate_scope(_scope), do: {:error, :invalid_scope}

  defp iso8601_or_nil(nil), do: nil
  defp iso8601_or_nil(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
  defp hash(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
  defp random_token(bytes), do: bytes |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
