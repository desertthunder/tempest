defmodule Tempest.Lexicon.ExternalResolver.Disabled do
  @moduledoc """
  Default external Lexicon resolver.

  This resolver performs no network or dynamic lookup. It exists so the
  registry has an explicit disabled policy path instead of treating missing
  configuration as implicit permission to resolve schemas externally.
  """

  @behaviour Tempest.Lexicon.ExternalResolver

  @impl true
  def resolve(_id, _opts), do: {:error, :disabled}
end
