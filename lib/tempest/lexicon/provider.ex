defmodule Tempest.Lexicon.Provider do
  @moduledoc """
  Boundary for trusted local Lexicon document sources.

  Providers return decoded Lexicon documents plus optional source metadata.
  The registry owns validation, duplicate detection, and source composition
  so record validation never needs to know where a schema came from.
  """

  @type manifest :: map()
  @type load_result :: {:ok, [map()], manifest() | nil} | {:error, term()}

  @callback load(Keyword.t()) :: load_result()
end
