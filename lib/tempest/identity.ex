defmodule Tempest.Identity do
  @moduledoc """
  Account identity, DID document, and handle resolution boundary.
  """

  import Ecto.Query

  alias Tempest.Accounts.{Account, AuthContext}
  alias Tempest.Identity.{DidDocument, HandleResolver, KeyStore, Validators}
  alias Tempest.{Repo, Sequencer}

  def validate_did_syntax(did), do: Validators.validate_did(did)
  def validate_handle_syntax(handle), do: Validators.validate_handle(handle)

  def generate_hosted_did do
    suffix =
      16
      |> :crypto.strong_rand_bytes()
      |> Base.encode32(case: :lower, padding: false)

    "did:plc:" <> suffix
  end

  def create_initial_signing_key(%Account{} = account), do: KeyStore.create_initial_key(account)

  def did_document_for_account(%Account{} = account), do: DidDocument.build(account)

  def did_document_for_did(did) when is_binary(did) do
    case Repo.get_by(Account, did: did) do
      %Account{} = account -> {:ok, did_document_for_account(account)}
      nil -> {:error, :did_not_found}
    end
  end

  def hosted_did_for_handle(handle) when is_binary(handle) do
    handle = Validators.normalize_handle(handle)

    Account
    |> where([account], account.handle == ^handle and account.active and account.status == "active")
    |> select([account], account.did)
    |> Repo.one()
    |> case do
      nil -> {:error, :handle_not_found}
      did -> {:ok, did}
    end
  end

  def resolve_handle(handle) when is_binary(handle) do
    handle = Validators.normalize_handle(handle)

    with :ok <- Validators.validate_handle(handle) do
      case local_resolve_handle(handle) do
        {:ok, did} -> {:ok, did}
        {:error, :handle_not_found} -> HandleResolver.resolve(handle)
      end
    end
  end

  def resolve_handle(_handle), do: {:error, :invalid_handle_syntax}

  def update_handle(%AuthContext{account: %Account{} = account}, handle) when is_binary(handle) do
    handle = Validators.normalize_handle(handle)
    did = account.did

    with :ok <- Validators.validate_handle(handle),
         {:ok, ^did} <- resolve_handle(handle),
         {:ok, document} <- did_document_for_did(did),
         true <- DidDocument.claims_handle?(document, handle),
         {:ok, updated_account} <- persist_handle(account, handle) do
      with {:ok, _event} <- Sequencer.insert_identity_event(did, "handle.update", %{"handle" => handle}) do
        {:ok, updated_account}
      end
    else
      {:ok, _other_did} -> {:error, :handle_did_mismatch}
      false -> {:error, :did_document_mismatch}
      {:error, reason} -> {:error, reason}
    end
  end

  def update_handle(_auth_context, _handle), do: {:error, :invalid_handle_syntax}

  defp local_resolve_handle(handle) do
    Account
    |> where([account], account.handle == ^handle and account.active and account.status == "active")
    |> Repo.one()
    |> case do
      %Account{} = account ->
        document = did_document_for_account(account)

        if DidDocument.claims_handle?(document, handle) do
          {:ok, account.did}
        else
          {:error, :did_document_mismatch}
        end

      nil ->
        {:error, :handle_not_found}
    end
  end

  defp persist_handle(%Account{} = account, handle) do
    account
    |> Account.update_handle_changeset(%{"handle" => handle})
    |> Repo.update()
  end
end
