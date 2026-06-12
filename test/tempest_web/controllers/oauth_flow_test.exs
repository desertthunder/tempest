defmodule TempestWeb.OAuthFlowTest do
  use TempestWeb.ConnCase, async: false

  alias Tempest.Accounts
  alias Tempest.OAuth.Dpop

  @password "correct horse battery staple"
  @client_id "did:web:client.example.com"
  @redirect_uri "https://client.example.com/cb"

  setup do
    {:ok, account} =
      Accounts.create_account(%{
        "handle" => "oauth-flow-#{System.unique_integer([:positive])}.test",
        "email" => "oauth-flow-#{System.unique_integer([:positive])}@example.com",
        "password" => @password
      })

    {:ok, account: account}
  end

  test "authorization-code flow issues scoped DPoP token and revokes it", %{conn: conn, account: account} do
    par_conn =
      conn
      |> put_req_header("dpop", dpop("POST", "http://localhost:4002/oauth/par", Dpop.issue_nonce()))
      |> post(~p"/oauth/par", %{
        "client_id" => @client_id,
        "redirect_uri" => @redirect_uri,
        "scope" => "atproto",
        "response_type" => "code",
        "code_challenge" => code_challenge("verifier"),
        "code_challenge_method" => "S256"
      })

    %{"request_uri" => request_uri} = json_response(par_conn, 200)

    authorize_conn =
      conn
      |> recycle()
      |> post(~p"/oauth/authorize", %{
        "request_uri" => request_uri,
        "identifier" => account["handle"],
        "password" => @password
      })

    [location] = get_resp_header(authorize_conn, "location")
    code = location |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query() |> Map.fetch!("code")

    token_conn =
      conn
      |> recycle()
      |> put_req_header("dpop", dpop("POST", "http://localhost:4002/oauth/token", Dpop.issue_nonce()))
      |> post(~p"/oauth/token", %{
        "grant_type" => "authorization_code",
        "client_id" => @client_id,
        "redirect_uri" => @redirect_uri,
        "code" => code,
        "code_verifier" => "verifier"
      })

    token_response = json_response(token_conn, 200)

    assert token_response["token_type"] == "DPoP"
    assert token_response["scope"] == "atproto"
    assert token_response["sub"] == account["did"]
    assert is_binary(token_response["access_token"])

    revoke_conn =
      conn
      |> recycle()
      |> post(~p"/oauth/revoke", %{"token" => token_response["access_token"], "client_id" => @client_id})

    assert response(revoke_conn, 200) == ""
  end

  defp dpop(method, url, nonce), do: Tempest.DpopProof.proof(method, url, nonce)

  defp code_challenge(verifier) do
    :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false)
  end
end
