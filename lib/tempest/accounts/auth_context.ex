defmodule Tempest.Accounts.AuthContext do
  @moduledoc """
  Authentication context assigned to XRPC connections.
  """

  @enforce_keys [:account, :token_type]
  defstruct [:account, :token_type, :session, :access_claims, :credential]
end
