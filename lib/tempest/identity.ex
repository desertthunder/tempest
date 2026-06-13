defmodule Tempest.Identity do
  @moduledoc """
  Account identity, DID document, and handle resolution boundary.
  """

  import Ecto.Query

  alias Tempest.Accounts.{Account, AuthContext}

  alias Tempest.Identity.{
    Correctness,
    DidDocument,
    HandleResolver,
    KeyStore,
    PlcClient,
    PlcOperation,
    SsrfProtection,
    Validators
  }

  alias Tempest.{Repo, Sequencer}

  def validate_did_syntax(did), do: Validators.validate_did(did)
  def validate_handle_syntax(handle), do: Validators.validate_handle(handle)

  def generate_hosted_did do
    case Tempest.Config.load!().hosted_did_method do
      method when method in [:web, "web"] ->
        "did:web:" <> Tempest.Config.load!().hostname

      _plc ->
        "did:plc:" <>
          (16
           |> :crypto.strong_rand_bytes()
           |> Base.encode32(case: :lower, padding: false))
    end
  end

  def create_initial_signing_key(%Account{} = account), do: KeyStore.create_initial_key(account)

  def recommended_did_credentials(%Account{} = account) do
    operation = PlcOperation.for_account(account)

    %{
      "did" => account.did,
      "handle" => account.handle,
      "signingKey" => get_in(operation, ["verificationMethods", "atproto"]),
      "rotationKeys" => operation["rotationKeys"],
      "verificationMethods" => operation["verificationMethods"],
      "alsoKnownAs" => operation["alsoKnownAs"],
      "services" => operation["services"]
    }
  end

  def sign_plc_operation(%Account{} = account, token, operation_fields) when is_map(operation_fields) do
    operation =
      account
      |> PlcOperation.for_account(prev: current_plc_prev(account))
      |> Map.merge(
        Map.take(operation_fields, ["rotationKeys", "alsoKnownAs", "verificationMethods", "services", "prev"])
      )

    with :ok <- Correctness.check_local(account),
         {:ok, _token_record} <- Tempest.Security.consume_plc_operation_token(account, token),
         {:ok, signed_operation} <- PlcOperation.sign(account, operation),
         {:ok, _event} <- Tempest.Security.log_event(account, "plc_operation.signed", %{}) do
      {:ok, signed_operation}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def sign_plc_operation(%Account{}, _token, _operation_fields), do: {:error, :invalid_operation}

  def submit_plc_operation(%Account{} = account, operation) do
    with :ok <- Correctness.check_local(account),
         :ok <- PlcOperation.validate_signed_for_account(account, operation),
         :ok <- PlcClient.publish_operation(account.did, operation),
         {:ok, _audit_event} <- Tempest.Security.log_event(account, "plc_operation.submitted", %{}),
         {:ok, _identity_event} <-
           Sequencer.insert_identity_event(account.did, "plc.submit", %{"handle" => account.handle}) do
      :ok
    else
      {:error, reason} ->
        Tempest.Security.log_event(account, "plc_operation.submit_failed", %{reason: inspect(reason)})
        {:error, reason}
    end
  end

  def publish_plc_operation(%Account{} = account) do
    with true <- String.starts_with?(account.did, "did:plc:"),
         :ok <- Correctness.check_local(account),
         operation = PlcOperation.for_account(account, prev: current_plc_prev(account)),
         :ok <- PlcClient.publish_operation(account.did, operation) do
      :ok
    else
      false -> {:error, :unsupported_did_method}
      {:error, reason} -> {:error, reason}
    end
  end

  def did_document_for_account(%Account{} = account), do: DidDocument.build(account)

  def did_document_for_did(did) when is_binary(did) do
    case Repo.get_by(Account, did: did) do
      %Account{} = account -> {:ok, did_document_for_account(account)}
      nil -> resolve_did_document(did)
    end
  end

  def did_document_for_did(_did), do: {:error, :invalid_did_syntax}

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

  defp current_plc_prev(%Account{did: "did:plc:" <> _} = account) do
    if fetch_existing_plc_state?() do
      case PlcClient.fetch_state(account.did) do
        {:ok, %{"cid" => cid}} when is_binary(cid) and cid != "" -> cid
        {:ok, %{"prev" => prev}} when is_binary(prev) and prev != "" -> prev
        {:ok, _state} -> nil
        {:error, _reason} -> nil
      end
    end
  end

  defp current_plc_prev(%Account{}), do: nil

  defp fetch_existing_plc_state? do
    config = Application.get_env(:tempest, Tempest.Identity, [])

    if Keyword.has_key?(config, :fetch_existing_plc_state) do
      Keyword.fetch!(config, :fetch_existing_plc_state)
    else
      Application.get_env(:tempest, :env, :prod) != :test
    end
  end

  defp resolve_did_document(did) do
    with :ok <- Validators.validate_did(did),
         {:ok, url} <- did_document_url(did),
         :ok <- SsrfProtection.validate_url(url),
         {:ok, document} <- fetch_did_document(url),
         ^did <- Map.get(document, "id") do
      {:ok, document}
    else
      {:error, reason} -> {:error, reason}
      _other -> {:error, :did_not_found}
    end
  end

  defp did_document_url("did:web:" <> identifier) do
    parts = String.split(identifier, ":")

    case parts do
      [host] -> {:ok, "https://#{host}/.well-known/did.json"}
      [host | path_parts] -> {:ok, "https://#{host}/#{Enum.join(path_parts, "/")}/did.json"}
      _parts -> {:error, :invalid_did_syntax}
    end
  end

  defp did_document_url("did:plc:" <> _identifier = did), do: {:ok, plc_directory_url() <> "/" <> URI.encode(did)}
  defp did_document_url(_did), do: {:error, :unsupported_did_method}

  defp fetch_did_document(url) do
    opts =
      [
        url: url,
        redirect: false,
        retry: false,
        receive_timeout: 2_000,
        connect_options: [timeout: 1_000]
      ]
      |> Keyword.merge(identity_config(:http_req_options) || [])

    case Req.get(opts) do
      {:ok, %{status: 200, body: body}} when is_map(body) -> {:ok, body}
      {:ok, %{status: 200, body: body}} when is_binary(body) -> Jason.decode(body)
      {:ok, _response} -> {:error, :did_not_found}
      {:error, _reason} -> {:error, :resolution_failed}
    end
  end

  defp plc_directory_url do
    identity_config(:plc_directory_url) || "https://plc.directory"
  end

  defp identity_config(key) do
    :tempest
    |> Application.get_env(Tempest.Identity, [])
    |> Keyword.get(key)
  end

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
