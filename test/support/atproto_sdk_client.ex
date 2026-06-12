defmodule Tempest.AtprotoSdkClient do
  @moduledoc """
  Tiny HTTP-only AT Protocol client used by local-server compatibility tests.

  It intentionally talks to Tempest through public HTTP endpoints instead of
  calling contexts, so tests exercise black-box client behavior without adding a
  Node or Python SDK dependency to the Mix project.
  """

  defstruct [:base_url]

  def new(base_url) when is_binary(base_url), do: %__MODULE__{base_url: String.trim_trailing(base_url, "/")}

  def create_account(client, attrs), do: post_json(client, "/xrpc/com.atproto.server.createAccount", attrs)

  def create_session(client, identifier, password) do
    post_json(client, "/xrpc/com.atproto.server.createSession", %{"identifier" => identifier, "password" => password})
  end

  def create_record(client, token, attrs, headers \\ []) do
    post_json(client, "/xrpc/com.atproto.repo.createRecord", attrs, auth_headers(token) ++ headers)
  end

  def get_record(client, params) do
    get_json(client, "/xrpc/com.atproto.repo.getRecord", params)
  end

  def upload_blob(client, token, bytes, content_type \\ "text/plain") when is_binary(bytes) do
    response =
      Req.post!(url(client, "/xrpc/com.atproto.repo.uploadBlob"),
        headers: auth_headers(token) ++ [{"content-type", content_type}],
        body: bytes
      )

    decode_response(response)
  end

  def get_repo(client, did) do
    Req.get!(url(client, "/xrpc/com.atproto.sync.getRepo"), params: %{"did" => did})
  end

  def get_blob(client, did, cid) do
    Req.get!(url(client, "/xrpc/com.atproto.sync.getBlob"), params: %{"did" => did, "cid" => cid})
  end

  def create_app_password(client, token, attrs) do
    post_json(client, "/xrpc/com.atproto.server.createAppPassword", attrs, auth_headers(token))
  end

  def oauth_par(client, attrs, dpop) do
    post_form(client, "/oauth/par", attrs, [{"dpop", dpop}])
  end

  def oauth_authorize(client, attrs) do
    Req.post!(url(client, "/oauth/authorize"), form: attrs, redirect: false)
  end

  def oauth_token(client, attrs, dpop) do
    post_form(client, "/oauth/token", attrs, [{"dpop", dpop}])
  end

  def oauth_revoke(client, attrs) do
    Req.post!(url(client, "/oauth/revoke"), form: attrs)
  end

  defp get_json(client, path, params) do
    client
    |> url(path)
    |> Req.get!(params: params)
    |> decode_response()
  end

  defp post_json(client, path, body, headers \\ []) do
    client
    |> url(path)
    |> Req.post!(json: body, headers: headers)
    |> decode_response()
  end

  defp post_form(client, path, body, headers) do
    client
    |> url(path)
    |> Req.post!(form: body, headers: headers)
    |> decode_response()
  end

  defp decode_response(%Req.Response{status: status, body: body, headers: headers}) do
    %{status: status, body: body, headers: headers}
  end

  defp auth_headers(token), do: [{"authorization", "Bearer #{token}"}]
  defp url(client, path), do: client.base_url <> path
end
