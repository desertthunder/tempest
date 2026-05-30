defmodule TempestWeb.OAuthMetadataController do
  use TempestWeb, :controller

  alias Tempest.OAuth.{Jwks, Metadata}

  def protected_resource(conn, _params) do
    json(conn, Metadata.protected_resource())
  end

  def authorization_server(conn, _params) do
    json(conn, Metadata.authorization_server())
  end

  def jwks(conn, _params) do
    json(conn, Jwks.public_jwks())
  end
end
