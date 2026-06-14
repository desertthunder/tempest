defmodule Tempest.Lexicon.KnownRecords do
  @moduledoc """
  Opt-in fallback for record collections that are known by policy but whose
  schema could not be resolved at write time.

  Configured record collections can be treated as known after
  the normal generic record checks have already verified `$type`,
  collection, and rkey syntax.
  """

  @registry_config Tempest.Lexicon.Registry
  @default_namespaces ["site.standard"]

  def known?(collection) when is_binary(collection) do
    collection in configured_records() or namespace_known?(collection, configured_namespaces())
  end

  def known?(_collection), do: false

  defp namespace_known?(collection, namespaces) do
    Enum.any?(namespaces, fn
      namespace when is_binary(namespace) ->
        collection == namespace or String.starts_with?(collection, namespace <> ".")

      _namespace ->
        false
    end)
  end

  defp configured_records do
    :tempest
    |> Application.get_env(@registry_config, [])
    |> Keyword.get(:known_records, [])
    |> Enum.filter(&is_binary/1)
  end

  defp configured_namespaces do
    :tempest
    |> Application.get_env(@registry_config, [])
    |> Keyword.get(:known_record_namespaces, @default_namespaces)
    |> Enum.filter(&is_binary/1)
  end
end
