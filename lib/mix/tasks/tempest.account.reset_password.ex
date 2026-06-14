defmodule Mix.Tasks.Tempest.Account.ResetPassword do
  @shortdoc "Resets a local account password without email"

  @moduledoc """
  Resets a local Tempest account password from an operator shell.

      mix tempest.account.reset_password --identifier did:plc:... --password-env NEW_TEMPEST_PASSWORD

  Options:

    * `--identifier` - required account DID, handle, or email.
    * `--password-env` - environment variable containing the new password.
      Defaults to `TEMPEST_PASSWORD`.

  The task revokes existing sessions after updating the password hash.
  """

  use Mix.Task

  import Ecto.Query

  alias Tempest.Accounts.{Account, Password, Session}
  alias Tempest.Repo

  @requirements ["app.start"]

  @impl true
  def run(args) do
    {opts, _rest, invalid} =
      OptionParser.parse(args,
        strict: [identifier: :string, password_env: :string],
        aliases: [i: :identifier]
      )

    if invalid != [] do
      Mix.raise("invalid options: #{inspect(invalid)}")
    end

    identifier = required_option(opts, :identifier)
    password_env = Keyword.get(opts, :password_env, "TEMPEST_PASSWORD")
    password = System.get_env(password_env) || Mix.raise("#{password_env} is not set")

    with :ok <- Password.validate(password),
         %Account{} = account <- account_by_identifier(identifier) do
      reset_password!(account, password)
      Mix.shell().info("reset password for #{account.did} handle=#{account.handle}; revoked active sessions")
    else
      nil -> Mix.raise("account not found for identifier #{identifier}")
      {:error, reason} when is_binary(reason) -> Mix.raise(reason)
    end
  end

  defp required_option(opts, key) do
    Keyword.get(opts, key) || Mix.raise("--#{String.replace(Atom.to_string(key), "_", "-")} is required")
  end

  defp account_by_identifier(identifier) do
    normalized = identifier |> String.trim() |> String.downcase()

    Repo.one(
      from account in Account,
        where: account.did == ^identifier or account.handle == ^normalized or account.email == ^normalized
    )
  end

  defp reset_password!(%Account{} = account, password) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.transaction(fn ->
      account
      |> Ecto.Changeset.change(%{password_hash: Password.hash(password)})
      |> Repo.update!()

      Session
      |> where([session], session.account_id == ^account.id and is_nil(session.revoked_at))
      |> Repo.update_all(set: [revoked_at: now])
    end)
  end
end
