defmodule Tempest.Lexicon.ExternalResolver.Network do
  @moduledoc """
  Network-backed resolver for published Lexicon schema records.

  The resolver follows the AT Protocol publication model:

  1. derive the NSID authority by removing the final segment from the requested
     schema id and reversing it into a domain;
  2. read `_lexicon.<domain>` DNS TXT records for a `did=<did>` authority;
  3. resolve the DID document and find the `AtprotoPersonalDataServer` service;
  4. fetch the `com.atproto.lexicon.schema` record with rkey equal to the
     requested NSID from that PDS.

  All outbound URLs pass through `Tempest.Identity.SsrfProtection`, redirects are
  rejected, HTTP calls have conservative timeouts, responses are size-bounded,
  and positive/negative cache entries are stored in ETS. Positive entries can be
  served stale while a refresh fails; negative entries prevent repeated misses.
  Concurrent refreshes for the same NSID are serialized with `:global.trans/2`.
  """

  @behaviour Tempest.Lexicon.ExternalResolver

  alias Tempest.Identity.{SsrfProtection, Validators}

  @cache_table :tempest_lexicon_external_resolver_cache
  @txt_prefix "did="
  @schema_collection "com.atproto.lexicon.schema"

  @default_opts [
    positive_ttl_ms: 300_000,
    negative_ttl_ms: 60_000,
    stale_ttl_ms: 900_000,
    max_response_bytes: 256_000,
    receive_timeout: 2_000,
    connect_timeout: 1_000,
    req_options: []
  ]

  @impl true
  def resolve(id, opts) when is_binary(id) do
    opts = Keyword.merge(@default_opts, opts)
    ensure_cache!()
    now = monotonic_ms()

    case lookup_cache(id, now) do
      {:fresh, document} -> {:ok, document}
      {:negative, reason} -> {:error, reason}
      {:stale, document} -> refresh_with_single_flight(id, opts, document)
      :miss -> refresh_with_single_flight(id, opts, nil)
    end
  end

  def resolve(_id, _opts), do: {:error, :invalid_ref}

  def reset_cache! do
    ensure_cache!()
    :ets.delete_all_objects(@cache_table)
    :ok
  end

  defp refresh_with_single_flight(id, opts, stale_document) do
    lock = {:lock, id}
    acquire_lock(lock)

    try do
      now = monotonic_ms()

      case lookup_cache(id, now) do
        {:fresh, document} ->
          {:ok, document}

        {:negative, reason} ->
          {:error, reason}

        _miss_or_stale ->
          case resolve_uncached(id, opts) do
            {:ok, document} ->
              put_positive_cache(id, document, opts)
              {:ok, document}

            {:error, reason} ->
              put_negative_cache(id, reason, opts)

              if is_map(stale_document) do
                {:ok, stale_document}
              else
                {:error, reason}
              end
          end
      end
    after
      :ets.delete(@cache_table, lock)
    end
  end

  defp acquire_lock(lock) do
    if :ets.insert_new(@cache_table, {lock, self()}) do
      :ok
    else
      Process.sleep(5)
      acquire_lock(lock)
    end
  end

  defp resolve_uncached(id, opts) do
    with {:ok, domain} <- authority_domain(id),
         {:ok, did} <- resolve_lexicon_did(domain, opts),
         {:ok, did_document} <- resolve_did_document(did, opts),
         {:ok, service_endpoint} <- pds_service_endpoint(did_document),
         :ok <- SsrfProtection.validate_url(service_endpoint),
         {:ok, document} <- fetch_schema_record(service_endpoint, did, id, opts),
         {:ok, ^id} <- fetch_matching_id(document, id) do
      {:ok, document}
    else
      {:ok, other_id} -> {:error, {:resolved_lexicon_id_mismatch, id, other_id}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp authority_domain(id) do
    parts = String.split(id, ".")

    if length(parts) >= 3 do
      parts
      |> Enum.drop(-1)
      |> Enum.reverse()
      |> Enum.join(".")
      |> then(&{:ok, &1})
    else
      {:error, :invalid_ref}
    end
  end

  defp resolve_lexicon_did(domain, opts) do
    query = "_lexicon." <> domain

    query
    |> dns_txt_lookup(opts)
    |> Enum.find_value(fn record ->
      record
      |> txt_record_to_string()
      |> parse_txt_did()
    end)
    |> case do
      nil -> {:error, :not_found}
      did -> validate_did(did)
    end
  end

  defp resolve_did_document(did, opts) do
    case Keyword.get(opts, :did_document_lookup) do
      fun when is_function(fun, 1) ->
        fun.(did)

      nil ->
        fetch_did_document(did, opts)
    end
  end

  defp fetch_did_document("did:web:" <> identifier, opts) do
    host = String.replace(identifier, ":", ".")
    url = "https://#{host}/.well-known/did.json"

    with :ok <- SsrfProtection.validate_url(url) do
      fetch_json(url, opts)
    end
  end

  defp fetch_did_document("did:plc:" <> _identifier = did, opts) do
    url = "https://plc.directory/#{URI.encode(did, &URI.char_unreserved?/1)}"

    with :ok <- SsrfProtection.validate_url(url) do
      fetch_json(url, opts)
    end
  end

  defp fetch_did_document(_did, _opts), do: {:error, :unsupported_did_method}

  defp pds_service_endpoint(%{"service" => services}) when is_list(services) do
    services
    |> Enum.find_value(fn
      %{"type" => "AtprotoPersonalDataServer", "serviceEndpoint" => endpoint} when is_binary(endpoint) -> endpoint
      _service -> nil
    end)
    |> case do
      nil -> {:error, :pds_service_not_found}
      endpoint -> {:ok, endpoint}
    end
  end

  defp pds_service_endpoint(_document), do: {:error, :pds_service_not_found}

  defp fetch_schema_record(service_endpoint, did, id, opts) do
    case Keyword.get(opts, :schema_record_lookup) do
      fun when is_function(fun, 3) ->
        with {:ok, %{"value" => value}} when is_map(value) <- fun.(service_endpoint, did, id) do
          {:ok, Map.delete(value, "$type")}
        else
          {:ok, _body} -> {:error, :invalid_lexicon}
          {:error, reason} -> {:error, reason}
        end

      nil ->
        query =
          URI.encode_query(%{
            "repo" => did,
            "collection" => @schema_collection,
            "rkey" => id
          })

        url = String.trim_trailing(service_endpoint, "/") <> "/xrpc/com.atproto.repo.getRecord?" <> query

        with :ok <- SsrfProtection.validate_url(url),
             {:ok, %{"value" => value}} when is_map(value) <- fetch_json(url, opts) do
          {:ok, Map.delete(value, "$type")}
        else
          {:ok, _body} -> {:error, :invalid_lexicon}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp fetch_matching_id(%{"id" => id}, id), do: {:ok, id}
  defp fetch_matching_id(%{"id" => other_id}, _id) when is_binary(other_id), do: {:ok, other_id}
  defp fetch_matching_id(_document, _id), do: {:error, :invalid_lexicon}

  defp fetch_json(url, opts) do
    req_opts =
      [
        url: url,
        redirect: false,
        retry: false,
        receive_timeout: opts[:receive_timeout],
        connect_options: [timeout: opts[:connect_timeout]]
      ]
      |> Keyword.merge(opts[:req_options])

    case Req.get(req_opts) do
      {:ok, %{status: 200, body: body}} ->
        with :ok <- validate_response_size(body, opts),
             {:ok, decoded} <- decode_json_body(body) do
          {:ok, decoded}
        end

      {:ok, %{status: status}} when status in [301, 302, 303, 307, 308] ->
        {:error, :redirect_rejected}

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      {:ok, _response} ->
        {:error, :resolution_failed}

      {:error, _reason} ->
        {:error, :resolution_failed}
    end
  end

  defp validate_response_size(body, opts) when is_binary(body) do
    if byte_size(body) <= opts[:max_response_bytes], do: :ok, else: {:error, :response_too_large}
  end

  defp validate_response_size(body, opts) do
    body
    |> Jason.encode!()
    |> validate_response_size(opts)
  end

  defp decode_json_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, _reason} -> {:error, :invalid_json}
    end
  end

  defp decode_json_body(body) when is_map(body), do: {:ok, body}
  defp decode_json_body(_body), do: {:error, :invalid_json}

  defp lookup_cache(id, now) do
    case :ets.lookup(@cache_table, id) do
      [{^id, {:positive, document, expires_at, _stale_until}}] when now <= expires_at ->
        {:fresh, document}

      [{^id, {:positive, document, _expires_at, stale_until}}] when now <= stale_until ->
        {:stale, document}

      [{^id, {:negative, reason, expires_at}}] when now <= expires_at ->
        {:negative, reason}

      _other ->
        :miss
    end
  end

  defp put_positive_cache(id, document, opts) do
    now = monotonic_ms()
    expires_at = now + opts[:positive_ttl_ms]
    stale_until = expires_at + opts[:stale_ttl_ms]
    :ets.insert(@cache_table, {id, {:positive, document, expires_at, stale_until}})
  end

  defp put_negative_cache(id, reason, opts) do
    :ets.insert(@cache_table, {id, {:negative, reason, monotonic_ms() + opts[:negative_ttl_ms]}})
  end

  defp ensure_cache! do
    case :ets.whereis(@cache_table) do
      :undefined -> :ets.new(@cache_table, [:named_table, :public, read_concurrency: true])
      _tid -> @cache_table
    end
  end

  defp monotonic_ms, do: System.monotonic_time(:millisecond)

  defp dns_txt_lookup(query, opts) do
    case Keyword.get(opts, :dns_txt_lookup) do
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

  defp validate_did(did) do
    case Validators.validate_did(did) do
      :ok -> {:ok, did}
      {:error, reason} -> {:error, reason}
    end
  end
end
