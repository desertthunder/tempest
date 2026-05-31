defmodule Tempest.Identity.Correctness do
  @moduledoc """
  Verifies local and network-facing identity consistency.
  """

  alias Tempest.Accounts.Account
  alias Tempest.Identity.{DidDocument, HandleResolver, Validators}

  def check_local(%Account{} = account) do
    document = DidDocument.build(account)

    with :ok <- Validators.validate_did(account.did),
         :ok <- verify_document_id(document, account.did),
         :ok <- verify_service_endpoint(document),
         :ok <- verify_handle_claim(document, account.handle) do
      :ok
    end
  end

  def check_handle(%Account{} = account) do
    with :ok <- check_local(account),
         {:ok, did} <- HandleResolver.resolve(account.handle),
         true <- did == account.did do
      :ok
    else
      false -> {:error, :handle_did_mismatch}
      {:error, reason} -> {:error, reason}
    end
  end

  def service_endpoint(%{"service" => services}) when is_list(services) do
    services
    |> Enum.find(fn service -> service["id"] == "#atproto_pds" end)
    |> case do
      %{"serviceEndpoint" => endpoint} when is_binary(endpoint) -> {:ok, endpoint}
      _other -> {:error, :missing_pds_service}
    end
  end

  def service_endpoint(_document), do: {:error, :missing_pds_service}

  defp verify_document_id(%{"id" => did}, did), do: :ok
  defp verify_document_id(_document, _did), do: {:error, :did_document_mismatch}

  defp verify_service_endpoint(document) do
    with {:ok, endpoint} <- service_endpoint(document) do
      if endpoint == normalized_public_url() do
        :ok
      else
        {:error, :pds_service_mismatch}
      end
    end
  end

  defp verify_handle_claim(document, handle) do
    if DidDocument.claims_handle?(document, handle), do: :ok, else: {:error, :handle_claim_missing}
  end

  defp normalized_public_url do
    %{scheme: scheme, host: host, port: port} = URI.parse(Tempest.Config.load!().public_url)
    default_port? = (scheme == "http" and port in [nil, 80]) or (scheme == "https" and port in [nil, 443])

    if default_port?, do: "#{scheme}://#{host}", else: "#{scheme}://#{host}:#{port}"
  end
end
