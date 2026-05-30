defmodule TempestWeb.OAuthController do
  use TempestWeb, :controller

  alias Tempest.OAuth
  alias Tempest.OAuth.Dpop

  def par(conn, params) do
    public_url = Tempest.Config.load!().public_url
    dpop = conn |> get_req_header("dpop") |> List.first()

    case OAuth.create_par(params, dpop, public_url) do
      {:ok, par} ->
        conn
        |> put_resp_header("dpop-nonce", Dpop.issue_nonce())
        |> json(%{"request_uri" => par.request_uri, "expires_in" => 600})

      {:error, :invalid_dpop_nonce} ->
        conn
        |> put_resp_header("dpop-nonce", Dpop.issue_nonce())
        |> put_status(401)
        |> json(%{"error" => "use_dpop_nonce", "error_description" => "DPoP nonce is required or has expired"})

      {:error, :missing_dpop} ->
        conn
        |> put_resp_header("dpop-nonce", Dpop.issue_nonce())
        |> put_status(401)
        |> json(%{"error" => "invalid_dpop_proof", "error_description" => "DPoP proof is required"})

      {:error, :invalid_scope} ->
        conn |> put_status(400) |> json(%{"error" => "invalid_scope"})

      {:error, _reason} ->
        conn |> put_status(400) |> json(%{"error" => "invalid_request"})
    end
  end

  def authorize(conn, %{"request_uri" => request_uri}) do
    case OAuth.get_valid_par(request_uri) do
      {:ok, par} ->
        html(conn, authorization_page(par, nil))

      {:error, _reason} ->
        conn |> put_status(400) |> html("invalid request_uri")
    end
  end

  def authorize(conn, _params), do: conn |> put_status(400) |> html("request_uri is required")

  def approve(conn, params) do
    case OAuth.authorize(params) do
      {:ok, %{redirect: redirect}} ->
        redirect(conn, external: redirect)

      {:error, :invalid_credentials} ->
        with {:ok, par} <- OAuth.get_valid_par(Map.get(params, "request_uri")) do
          conn |> put_status(401) |> html(authorization_page(par, "Invalid identifier or password"))
        else
          _error -> conn |> put_status(400) |> html("invalid request_uri")
        end

      {:error, _reason} ->
        conn |> put_status(400) |> html("authorization failed")
    end
  end

  def token(conn, params) do
    public_url = Tempest.Config.load!().public_url
    dpop = conn |> get_req_header("dpop") |> List.first()

    result =
      case Map.get(params, "grant_type") do
        "authorization_code" -> OAuth.exchange_authorization_code(params, dpop, public_url)
        "refresh_token" -> OAuth.refresh(params, dpop, public_url)
        _other -> {:error, :unsupported_grant_type}
      end

    case result do
      {:ok, response} ->
        conn
        |> put_resp_header("dpop-nonce", Dpop.issue_nonce())
        |> json(response)

      {:error, :invalid_dpop_nonce} ->
        conn
        |> put_resp_header("dpop-nonce", Dpop.issue_nonce())
        |> put_status(401)
        |> json(%{"error" => "use_dpop_nonce"})

      {:error, :unsupported_grant_type} ->
        conn |> put_status(400) |> json(%{"error" => "unsupported_grant_type"})

      {:error, :invalid_grant} ->
        conn |> put_status(400) |> json(%{"error" => "invalid_grant"})

      {:error, _reason} ->
        conn |> put_status(400) |> json(%{"error" => "invalid_request"})
    end
  end

  def revoke(conn, params) do
    :ok = OAuth.revoke(Map.get(params, "token", ""))
    send_resp(conn, 200, "")
  end

  defp authorization_page(par, error) do
    escaped_client = Phoenix.HTML.html_escape(par.client_id) |> Phoenix.HTML.safe_to_string()
    escaped_scope = Phoenix.HTML.html_escape(par.scope) |> Phoenix.HTML.safe_to_string()
    escaped_request_uri = Phoenix.HTML.html_escape(par.request_uri) |> Phoenix.HTML.safe_to_string()

    error_html =
      if error do
        escaped_error = Phoenix.HTML.html_escape(error) |> Phoenix.HTML.safe_to_string()
        ~s(<p id="oauth-error" style="color:#b91c1c">#{escaped_error}</p>)
      else
        ""
      end

    """
    <!doctype html>
    <html lang="en">
      <head><meta charset="utf-8"><title>Authorize OAuth client</title></head>
      <body style="font-family: system-ui, sans-serif; max-width: 42rem; margin: 4rem auto; padding: 0 1rem;">
        <main id="oauth-authorization">
          <p style="letter-spacing:.08em;text-transform:uppercase;color:#64748b;font-size:.75rem">Unknown OAuth client</p>
          <h1>Authorize external client</h1>
          <p>This client is identified only by its public metadata URL. Tempest has not verified its name, logo, or publisher.</p>
          <dl>
            <dt>Client ID</dt><dd><code>#{escaped_client}</code></dd>
            <dt>Requested scopes</dt><dd><code>#{escaped_scope}</code></dd>
          </dl>
          #{error_html}
          <form id="oauth-authorization-form" method="post" action="/oauth/authorize">
            <input type="hidden" name="request_uri" value="#{escaped_request_uri}">
            <label>Identifier <input name="identifier" autocomplete="username" required></label><br><br>
            <label>Password <input name="password" type="password" autocomplete="current-password" required></label><br><br>
            <button type="submit">Approve scopes</button>
          </form>
        </main>
      </body>
    </html>
    """
  end
end
