defmodule Tempest.PersonalBackups.SourceClient do
  @moduledoc """
  Read-only XRPC client for external source PDS backup reads.
  """

  @sync_get_repo "com.atproto.sync.getRepo"
  @sync_list_blobs "com.atproto.sync.listBlobs"
  @sync_get_blob "com.atproto.sync.getBlob"
  @get_preferences "app.bsky.actor.getPreferences"

  def get_repo(source_pds_url, did, opts \\ []) when is_binary(source_pds_url) and is_binary(did) do
    source_pds_url
    |> xrpc_url(@sync_get_repo, did: did)
    |> get_binary(opts)
  end

  def list_blobs(source_pds_url, did, opts \\ []) when is_binary(source_pds_url) and is_binary(did) do
    params =
      [did: did]
      |> maybe_put(:cursor, Keyword.get(opts, :cursor))
      |> maybe_put(:limit, Keyword.get(opts, :limit))

    source_pds_url
    |> xrpc_url(@sync_list_blobs, params)
    |> get_json(opts)
  end

  def get_blob(source_pds_url, did, cid, opts \\ [])
      when is_binary(source_pds_url) and is_binary(did) and is_binary(cid) do
    source_pds_url
    |> xrpc_url(@sync_get_blob, did: did, cid: cid)
    |> get_binary(opts)
  end

  def get_preferences(source_pds_url, access_token, opts \\ [])
      when is_binary(source_pds_url) and is_binary(access_token) do
    source_pds_url
    |> xrpc_url(@get_preferences, [])
    |> get_json(Keyword.put(opts, :authorization, "Bearer " <> access_token))
  end

  defp get_binary(url, opts) do
    request(url, opts)
    |> Req.get()
    |> case do
      {:ok, %{status: status, body: body}} when status in 200..299 and is_binary(body) ->
        {:ok, body}

      {:ok, %{status: status}} ->
        {:error, {:source_pds_http_error, status}}

      {:error, reason} ->
        {:error, {:source_pds_request_failed, reason}}
    end
  end

  defp get_json(url, opts) do
    request(url, opts)
    |> Req.get()
    |> case do
      {:ok, %{status: status, body: body}} when status in 200..299 and is_map(body) ->
        {:ok, body}

      {:ok, %{status: status, body: body}} when status in 200..299 and is_binary(body) ->
        Jason.decode(body)

      {:ok, %{status: status}} ->
        {:error, {:source_pds_http_error, status}}

      {:error, reason} ->
        {:error, {:source_pds_request_failed, reason}}
    end
  end

  defp request(url, opts) do
    headers =
      case Keyword.get(opts, :authorization) do
        nil -> []
        authorization -> [{"authorization", authorization}]
      end

    [
      url: url,
      headers: headers,
      redirect: false,
      retry: false,
      receive_timeout: 10_000,
      connect_options: [timeout: 2_000]
    ]
    |> Keyword.merge(client_config(:req_options) || [])
    |> Keyword.merge(Keyword.get(opts, :req_options, []))
    |> Req.new()
  end

  defp xrpc_url(source_pds_url, method, params) do
    source_pds_url
    |> String.trim_trailing("/")
    |> Kernel.<>("/xrpc/" <> method <> query_string(params))
  end

  defp query_string([]), do: ""

  defp query_string(params) do
    "?" <> URI.encode_query(params)
  end

  defp maybe_put(params, _key, nil), do: params
  defp maybe_put(params, key, value), do: Keyword.put(params, key, value)

  defp client_config(key) do
    :tempest
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(key)
  end
end
