defmodule TempestWeb.PageController do
  use TempestWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
