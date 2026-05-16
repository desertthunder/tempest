defmodule Tempest.Lexicon.Registry do
  @moduledoc """
  Runtime lookup boundary for known Lexicon documents.

  The registry composes trusted local providers, validates their documents as
  a set, and exposes deterministic lookup by document id or definition ref.

  Source precedence is bundled generated schemas, configured in-memory documents,
  operator-configured local files/directories, then the configured external resolver
  if `external_resolver: [enabled?: true]` is set.

  External resolution is disabled by default. Even when enabled, a resolver is
  only consulted after local sources miss, so dynamic schemas cannot override
  bundled or operator-local schemas through the normal lookup path.
  """

  alias Tempest.Lexicon.Document

  @env_key __MODULE__
  @default_external_resolver [
    enabled?: false,
    resolver: Tempest.Lexicon.ExternalResolver.Network,
    opts: []
  ]
  @default_config [
    bundled?: true,
    bundled_provider: Tempest.Lexicon.Bundled,
    documents: [],
    paths: [],
    limits: [],
    external_resolver: @default_external_resolver
  ]

  def fetch(id) when is_binary(id) do
    case Map.fetch(local_documents!(), id) do
      {:ok, document} -> {:ok, document}
      :error -> fetch_external(id)
    end
  end

  def fetch_definition(ref, current_id \\ nil) when is_binary(ref) do
    with {:ok, id, name} <- parse_ref(ref, current_id),
         {:ok, document} <- fetch(id),
         {:ok, defs} <- fetch_map(document, "defs"),
         {:ok, definition} <- fetch_map(defs, name) do
      {:ok, document, definition}
    end
  end

  def fetch_record(collection) when is_binary(collection) do
    with {:ok, document, %{"type" => "record"} = definition} <- fetch_definition(collection) do
      {:ok, document, definition}
    else
      {:ok, _document, _definition} -> {:error, :not_record_lexicon}
      {:error, reason} -> {:error, reason}
    end
  end

  def normalize_ref("#" <> name, current_id) when is_binary(current_id), do: current_id <> "#" <> name
  def normalize_ref(ref, _current_id) when is_binary(ref), do: ref

  def manifest do
    config()
    |> load_sources()
    |> case do
      {:ok, _documents, manifests} -> {:ok, manifests}
      {:error, reason} -> {:error, reason}
    end
  end

  def validate_startup! do
    config()
    |> load_sources()
    |> case do
      {:ok, documents, _manifests} ->
        case Document.validate_documents(documents, limits()) do
          :ok -> :ok
          {:error, reason} -> raise ArgumentError, "invalid Lexicon documents: #{inspect(reason)}"
        end

      {:error, reason} ->
        raise ArgumentError, "invalid Lexicon registry configuration: #{inspect(reason)}"
    end
  end

  def validate_config(config) when is_list(config) do
    @default_config
    |> Keyword.merge(config)
    |> load_sources()
    |> case do
      {:ok, documents, _manifests} -> Document.validate_documents(documents, Keyword.get(config, :limits, []))
      {:error, reason} -> {:error, reason}
    end
  end

  defp local_documents! do
    config()
    |> load_sources()
    |> case do
      {:ok, documents, _manifests} ->
        case Document.validate_documents(documents, limits()) do
          :ok -> Map.new(documents, &{Map.fetch!(&1, "id"), &1})
          {:error, reason} -> raise ArgumentError, "invalid Lexicon documents: #{inspect(reason)}"
        end

      {:error, reason} ->
        raise ArgumentError, "invalid Lexicon registry configuration: #{inspect(reason)}"
    end
  end

  defp fetch_external(id) do
    config = config()
    resolver_config = Keyword.merge(@default_external_resolver, Keyword.get(config, :external_resolver, []))

    if Keyword.get(resolver_config, :enabled?, false) do
      resolver = Keyword.fetch!(resolver_config, :resolver)
      opts = Keyword.get(resolver_config, :opts, [])

      with {:ok, %{"id" => ^id} = document} <- resolver.resolve(id, opts),
           :ok <- Document.validate_documents([document], limits()) do
        {:ok, document}
      else
        {:ok, %{"id" => _other_id}} -> {:error, :unknown_lexicon}
        {:error, _reason} -> {:error, :unknown_lexicon}
        _other -> {:error, :invalid_lexicon}
      end
    else
      {:error, :unknown_lexicon}
    end
  end

  defp config do
    Keyword.merge(@default_config, Application.get_env(:tempest, @env_key, []))
  end

  defp limits do
    Keyword.get(config(), :limits, [])
  end

  defp load_sources(config) do
    with {:ok, bundled_documents, bundled_manifest} <- load_bundled(config),
         {:ok, configured_documents} <- normalize_documents(Keyword.get(config, :documents, [])),
         {:ok, local_documents, local_manifest} <-
           Tempest.Lexicon.LocalProvider.load(
             Keyword.merge(Keyword.get(config, :limits, []), paths: Keyword.get(config, :paths, []))
           ) do
      documents = bundled_documents ++ configured_documents ++ local_documents

      manifests =
        [bundled_manifest, local_manifest]
        |> Enum.reject(&is_nil/1)
        |> Enum.reject(&(Map.get(&1, "source") == "local" and Map.get(&1, "file_count") == 0))

      {:ok, documents, manifests}
    end
  end

  defp load_bundled(config) do
    if Keyword.get(config, :bundled?, true) do
      provider = Keyword.fetch!(config, :bundled_provider)
      provider.load(Keyword.get(config, :limits, []))
    else
      {:ok, [], nil}
    end
  end

  defp normalize_documents(documents) when is_list(documents) do
    if Enum.all?(documents, &is_map/1) do
      {:ok, documents}
    else
      {:error, :invalid_lexicon_documents}
    end
  end

  defp normalize_documents(documents) when is_map(documents) do
    values = Map.values(documents)

    if Enum.all?(values, &is_map/1) do
      {:ok, values}
    else
      {:error, :invalid_lexicon_documents}
    end
  end

  defp normalize_documents(_documents), do: {:error, :invalid_lexicon_documents}

  defp parse_ref("#" <> name, current_id) when is_binary(current_id), do: {:ok, current_id, name}
  defp parse_ref("#" <> _name, nil), do: {:error, :relative_ref_without_context}

  defp parse_ref(ref, _current_id) do
    case String.split(ref, "#", parts: 2) do
      [id] -> {:ok, id, "main"}
      [id, name] when id != "" and name != "" -> {:ok, id, name}
      _other -> {:error, :invalid_ref}
    end
  end

  defp fetch_map(map, key) do
    case Map.fetch(map, key) do
      {:ok, value} when is_map(value) -> {:ok, value}
      {:ok, _value} -> {:error, :invalid_lexicon}
      :error -> {:error, :unknown_lexicon}
    end
  end
end
