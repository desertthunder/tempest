defmodule Tempest.Permissions do
  @moduledoc """
  Centralized permission checks for sessions, OAuth tokens, app passwords, and
  future delegated access credentials.
  """

  alias Tempest.Accounts.AuthContext

  @account_management_methods MapSet.new([
                                "com.atproto.server.createAccount",
                                "com.atproto.server.createSession",
                                "com.atproto.server.refreshSession",
                                "com.atproto.server.deleteSession",
                                "com.atproto.server.getSession",
                                "com.atproto.identity.updateHandle",
                                "com.atproto.identity.getRecommendedDidCredentials",
                                "com.atproto.identity.requestPlcOperationSignature"
                              ])

  def allowed?(%AuthContext{token_type: token_type}, _method_nsid, _params)
      when token_type in [:access, :refresh],
      do: true

  def allowed?(%AuthContext{token_type: token_type} = context, method_nsid, params)
      when token_type in [:oauth_access, :app_password] do
    scopes = scopes(context)

    cond do
      MapSet.member?(@account_management_methods, method_nsid) ->
        false

      method_nsid == "com.atproto.repo.uploadBlob" ->
        scope_allowed?(scopes, "blob:*/*") or rpc_allowed?(scopes, method_nsid)

      method_nsid in [
        "com.atproto.repo.createRecord",
        "com.atproto.repo.putRecord",
        "com.atproto.repo.deleteRecord",
        "com.atproto.repo.applyWrites"
      ] ->
        write_allowed?(scopes, params) or rpc_allowed?(scopes, method_nsid)

      true ->
        coarse_allowed?(scopes) or rpc_allowed?(scopes, method_nsid)
    end
  end

  def allowed?(_context, _method_nsid, _params), do: false

  def scopes(%AuthContext{access_claims: %{"scope" => scope}}), do: split_scope(scope)
  def scopes(%AuthContext{access_claims: %{scope: scope}}), do: split_scope(scope)
  def scopes(_context), do: []

  defp split_scope(scope) when is_binary(scope), do: String.split(scope, " ", trim: true)
  defp split_scope(_scope), do: []

  defp coarse_allowed?(scopes) do
    Enum.any?(scopes, &(&1 in ["atproto", "transition:generic", "transition:chat.bsky", "transition:email"]))
  end

  defp write_allowed?(scopes, params) do
    coarse_allowed?(scopes) or collection_allowed?(scopes, collection_from_params(params))
  end

  defp collection_allowed?(_scopes, nil), do: false

  defp collection_allowed?(scopes, collection) do
    Enum.any?(scopes, fn
      "rpc:*" -> true
      "rpc:" <> _rpc -> false
      "blob:*/*" -> false
      scope -> scope == collection
    end)
  end

  defp rpc_allowed?(scopes, method_nsid) do
    Enum.any?(scopes, fn
      "rpc:*" -> true
      "rpc:" <> rpc_scope -> rpc_scope_matches?(rpc_scope, method_nsid)
      _scope -> false
    end)
  end

  defp rpc_scope_matches?(rpc_scope, method_nsid) do
    rpc_scope = rpc_scope |> String.split("?", parts: 2) |> List.first()

    cond do
      rpc_scope == "*" -> true
      rpc_scope == method_nsid -> true
      String.ends_with?(rpc_scope, ".*") -> String.starts_with?(method_nsid, String.trim_trailing(rpc_scope, "*"))
      true -> false
    end
  end

  defp scope_allowed?(scopes, required), do: required in scopes or coarse_allowed?(scopes)

  defp collection_from_params(%{"collection" => collection}) when is_binary(collection), do: collection

  defp collection_from_params(%{"writes" => [first | _rest]}) when is_map(first) do
    case Map.get(first, "collection") do
      collection when is_binary(collection) -> collection
      _other -> nil
    end
  end

  defp collection_from_params(_params), do: nil
end
