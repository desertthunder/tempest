defmodule Tempest.Lexicon.ExternalResolver do
  @moduledoc """
  Behaviour for policy-controlled external Lexicon resolution.

  External resolution is disabled by default. When enabled, the registry only
  asks the configured resolver after bundled, generated, and operator-local
  sources miss. A resolver must return a document whose `id` matches the
  requested NSID, and the registry validates that document before trusting it.

  Source precedence is:

  1. bundled generated schemas
  2. in-memory configured schemas, used by tests and controlled embedding
  3. operator-configured local schema files/directories
  4. external resolution, only when explicitly enabled

  External documents cannot override trusted local sources through this
  interface because the registry consults the resolver only after local lookup
  fails. Network resolution, caching, SSRF protections, and authority checks
  belong in concrete resolver implementations.
  """

  @type resolve_result :: {:ok, map()} | {:error, :not_found | :disabled | term()}

  @callback resolve(String.t(), Keyword.t()) :: resolve_result()
end
