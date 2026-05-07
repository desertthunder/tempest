defmodule Tempest.Xrpc.Method do
  @moduledoc """
  Metadata for a registered XRPC method.
  """

  @enforce_keys [:nsid, :kind, :auth, :input, :output, :handler, :errors]
  defstruct [:nsid, :kind, :auth, :input, :output, :handler, :errors]

  @type kind :: :query | :procedure | :subscription
  @type auth :: :none | :bearer | :admin
  @type handler :: {module(), atom()}
  @type content_type :: nil | String.t()

  @type t :: %__MODULE__{
          nsid: String.t(),
          kind: kind(),
          auth: auth(),
          input: content_type(),
          output: content_type(),
          handler: handler(),
          errors: [String.t()]
        }
end
