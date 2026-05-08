defmodule Tempest.Identity.HandleResolver do
  @moduledoc """
  Resolves AT Protocol handles through DNS TXT and HTTPS well-known metadata.
  """

  alias Tempest.Identity.{SsrfProtection, Validators}

  @txt_prefix "did="

  def resolve(handle) when is_binary(handle) do
    handle = Validators.normalize_handle(handle)

    with :ok <- Validators.validate_handle(handle) do
      case resolve_dns(handle) do
        {:ok, did} -> {:ok, did}
        {:error, _reason} -> resolve_https(handle)
      end
    end
  end

  def resolve(_handle), do: {:error, :invalid_handle_syntax}

  def resolve_dns(handle) do
    query = "_atproto." <> handle

    query
    |> dns_txt_lookup()
    |> Enum.find_value(fn record ->
      record
      |> txt_record_to_string()
      |> parse_txt_did()
    end)
    |> case do
      nil -> {:error, :handle_not_found}
      did -> validate_resolved_did(did)
    end
  end

  def resolve_https(handle) do
    url = "https://#{handle}/.well-known/atproto-did"

    with :ok <- SsrfProtection.validate_url(url),
         {:ok, body} <- fetch_plain_text(url),
         did = String.trim(body),
         {:ok, did} <- validate_resolved_did(did) do
      {:ok, did}
    end
  end

  defp fetch_plain_text(url) do
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
      {:ok, %{status: 200, body: body}} when is_binary(body) ->
        {:ok, body}

      {:ok, %{status: status}} when status in [301, 302, 303, 307, 308] ->
        {:error, :redirect_rejected}

      {:ok, _response} ->
        {:error, :handle_not_found}

      {:error, _reason} ->
        {:error, :resolution_failed}
    end
  end

  defp validate_resolved_did(did) do
    case Validators.validate_did(did) do
      :ok -> {:ok, did}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dns_txt_lookup(query) do
    case identity_config(:dns_txt_lookup) do
      nil -> :inet_res.lookup(String.to_charlist(query), :in, :txt)
      fun when is_function(fun, 1) -> fun.(query)
      {module, function, args} -> apply(module, function, [query | args])
    end
  rescue
    _error -> []
  end

  defp txt_record_to_string(record) when is_list(record) do
    record
    |> List.flatten()
    |> List.to_string()
  end

  defp txt_record_to_string(record) when is_binary(record), do: record
  defp txt_record_to_string(_record), do: ""

  defp parse_txt_did(@txt_prefix <> did), do: String.trim(did)
  defp parse_txt_did(_record), do: nil

  defp identity_config(key) do
    :tempest
    |> Application.get_env(Tempest.Identity, [])
    |> Keyword.get(key)
  end
end
