defmodule Tempest.Xrpc.NotImplemented do
  @moduledoc false

  def handle(_conn, _params, method) do
    {:error, 501, "NotImplemented", "#{method.nsid} is registered but not implemented"}
  end
end
