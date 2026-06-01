defmodule TempestWeb.OperatorAccountController do
  use TempestWeb, :controller

  alias Tempest.{Accounts, Blobs, RepoStorage, Sequencer}
  alias TempestWeb.XrpcErrorJSON

  @page_limit 50

  def dashboard(conn, _params) do
    with {:ok, auth} <- authenticate(conn),
         {:ok, status} <- Accounts.check_account_status(auth) do
      render(conn, :dashboard, account: auth.account, status: status)
    else
      {:error, reason} -> reject(conn, reason)
    end
  end

  def repo(conn, params) do
    with {:ok, auth} <- authenticate(conn),
         {:ok, collections} <- RepoStorage.list_collections(auth.account.did),
         {:ok, latest} <- RepoStorage.latest_commit(auth.account.did),
         {:ok, records} <- RepoStorage.list_recent_records(auth.account.did, limit: @page_limit) do
      render(conn, :repo,
        account: auth.account,
        collections: collections,
        latest: latest,
        records: records,
        selected_collection: Map.get(params, "collection")
      )
    else
      {:error, reason} -> reject(conn, reason)
    end
  end

  def blobs(conn, _params) do
    with {:ok, auth} <- authenticate(conn),
         {:ok, blobs} <- Blobs.list_all(auth.account.did, limit: @page_limit) do
      render(conn, :blobs, account: auth.account, blobs: blobs)
    else
      {:error, reason} -> reject(conn, reason)
    end
  end

  def sequencer(conn, params) do
    with {:ok, auth} <- authenticate(conn),
         {:ok, cursor} <- parse_cursor(Map.get(params, "cursor")),
         {:ok, events} <-
           Sequencer.list_after(cursor, limit: @page_limit, did: Map.get(params, "did"), type: Map.get(params, "type")) do
      render(conn, :sequencer,
        account: auth.account,
        events: events,
        cursor: cursor,
        did_filter: Map.get(params, "did"),
        type_filter: Map.get(params, "type")
      )
    else
      {:error, reason} -> reject(conn, reason)
    end
  end

  def firehose(conn, _params) do
    with {:ok, auth} <- authenticate(conn),
         {:ok, events} <- Sequencer.list_after(0, limit: 20, did: auth.account.did) do
      render(conn, :firehose,
        account: auth.account,
        events: events,
        websocket_url: websocket_url(conn)
      )
    else
      {:error, reason} -> reject(conn, reason)
    end
  end

  defp authenticate(conn) do
    conn
    |> get_req_header("authorization")
    |> case do
      ["Bearer " <> token] when token != "" -> Accounts.authenticate_access(token)
      ["bearer " <> token] when token != "" -> Accounts.authenticate_access(token)
      _headers -> {:error, :missing_token}
    end
  end

  defp parse_cursor(nil), do: {:ok, 0}

  defp parse_cursor(cursor) do
    case Integer.parse(cursor) do
      {value, ""} when value >= 0 -> {:ok, value}
      _other -> {:error, :invalid_cursor}
    end
  end

  defp websocket_url(conn) do
    scheme = if conn.scheme == :https, do: "wss", else: "ws"
    scheme <> "://" <> conn.host <> port_suffix(conn) <> "/xrpc/com.atproto.sync.subscribeRepos?cursor=0"
  end

  defp port_suffix(%{port: port, scheme: :http}) when port not in [80], do: ":#{port}"
  defp port_suffix(%{port: port, scheme: :https}) when port not in [443], do: ":#{port}"
  defp port_suffix(_conn), do: ""

  defp reject(conn, :missing_token),
    do: XrpcErrorJSON.render(conn, 401, "AuthenticationRequired", "Bearer token is required")

  defp reject(conn, :expired_token), do: XrpcErrorJSON.render(conn, 401, "ExpiredToken", "Bearer token is expired")
  defp reject(conn, :inactive_account), do: XrpcErrorJSON.render(conn, 403, "AccountTakedown", "Account is not active")

  defp reject(conn, :invalid_cursor),
    do: XrpcErrorJSON.render(conn, 400, "InvalidRequest", "cursor must be a non-negative integer")

  defp reject(conn, _reason), do: XrpcErrorJSON.render(conn, 401, "InvalidToken", "Bearer token is invalid")
end
