defmodule Tempest.Lexicon.Document do
  @moduledoc """
  Generic validation and indexing for Lexicon schema documents.

  This module validates the shape and reference graph of Lexicon data. It does
  not contain application-specific schemas.
  """

  alias Tempest.RepoCore.Nsid

  @default_limits [
    max_document_count: 1_000,
    max_definitions_per_document: 1_000,
    max_schema_depth: 64,
    max_ref_depth: 64
  ]

  @schema_types MapSet.new(
                  ~w(array blob boolean bytes cid-link integer object params permission procedure query record ref string subscription token union unknown)
                )

  def validate_documents(documents, opts \\ [])

  def validate_documents(documents, opts) when is_list(documents) do
    limits = Keyword.merge(@default_limits, opts)

    with :ok <- validate_document_count(documents, limits),
         :ok <- validate_each_document(documents, limits),
         :ok <- validate_unique_document_ids(documents),
         :ok <- validate_unique_definition_refs(documents),
         :ok <- validate_resolved_refs(documents),
         :ok <- validate_ref_graph(documents, limits) do
      :ok
    end
  end

  def validate_documents(_documents, _opts), do: {:error, :invalid_lexicon_documents}

  def validate_document(document, opts \\ [])

  def validate_document(%{"lexicon" => 1, "id" => id, "defs" => defs} = document, opts)
      when is_binary(id) and is_map(defs) do
    limits = Keyword.merge(@default_limits, opts)

    with :ok <- validate_nsid(id),
         :ok <- validate_defs_count(id, defs, limits),
         :ok <- validate_definitions(document, defs, limits) do
      :ok
    end
  end

  def validate_document(%{"lexicon" => version}, _opts) when version != 1,
    do: {:error, {:unsupported_lexicon_version, version}}

  def validate_document(_document, _opts), do: {:error, :invalid_lexicon_document}

  def definition_refs(%{"id" => id, "defs" => defs}) when is_binary(id) and is_map(defs) do
    defs
    |> Map.keys()
    |> Enum.sort()
    |> Enum.map(&build_ref(id, &1))
  end

  def definition_refs(_document), do: []

  def referenced_definition_refs(%{"id" => id, "defs" => defs}) when is_binary(id) and is_map(defs) do
    defs
    |> Enum.flat_map(fn {_name, schema} -> collect_refs(schema, id) end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  def referenced_definition_refs(_document), do: []

  def normalize_ref("#" <> name, current_id), do: build_ref(current_id, name)
  def normalize_ref(ref, _current_id) when is_binary(ref), do: normalize_ref_string(ref)

  defp validate_document_count(documents, limits) do
    if length(documents) <= limits[:max_document_count] do
      :ok
    else
      {:error, {:loader_limit_exceeded, :max_document_count}}
    end
  end

  defp validate_each_document(documents, limits) do
    Enum.reduce_while(documents, :ok, fn document, :ok ->
      case validate_document(document, limits) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp validate_unique_document_ids(documents) do
    documents
    |> Enum.map(&Map.get(&1, "id"))
    |> duplicates()
    |> case do
      [] -> :ok
      ids -> {:error, {:duplicate_document_ids, ids}}
    end
  end

  defp validate_unique_definition_refs(documents) do
    documents
    |> Enum.flat_map(&definition_refs/1)
    |> duplicates()
    |> case do
      [] -> :ok
      refs -> {:error, {:duplicate_definition_refs, refs}}
    end
  end

  defp validate_resolved_refs(documents) do
    known_refs = documents |> Enum.flat_map(&definition_refs/1) |> MapSet.new()

    documents
    |> Enum.flat_map(&referenced_definition_refs/1)
    |> Enum.reject(&MapSet.member?(known_refs, &1))
    |> Enum.uniq()
    |> Enum.sort()
    |> case do
      [] -> :ok
      refs -> {:error, {:unresolved_definition_refs, refs}}
    end
  end

  defp validate_ref_graph(documents, limits) do
    graph = definition_ref_graph(documents)

    graph
    |> Map.keys()
    |> Enum.sort()
    |> Enum.reduce_while(:ok, fn ref, :ok ->
      case walk_ref_graph(ref, graph, [], limits[:max_ref_depth]) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp definition_ref_graph(documents) do
    Map.new(documents, fn %{"id" => id, "defs" => defs} ->
      defs =
        Map.new(defs, fn {name, schema} ->
          {build_ref(id, name), collect_refs(schema, id)}
        end)

      {id, defs}
    end)
    |> Map.values()
    |> Enum.reduce(%{}, &Map.merge/2)
  end

  defp walk_ref_graph(ref, _graph, path, max_ref_depth) when length(path) > max_ref_depth do
    {:error, {:loader_limit_exceeded, :max_ref_depth, Enum.reverse([ref | path])}}
  end

  defp walk_ref_graph(ref, graph, path, max_ref_depth) do
    cond do
      ref in path ->
        cycle =
          path
          |> Enum.reverse()
          |> close_cycle(ref)

        {:error, {:ref_cycle, cycle}}

      true ->
        graph
        |> Map.get(ref, [])
        |> Enum.reduce_while(:ok, fn next_ref, :ok ->
          case walk_ref_graph(next_ref, graph, [ref | path], max_ref_depth) do
            :ok -> {:cont, :ok}
            {:error, reason} -> {:halt, {:error, reason}}
          end
        end)
    end
  end

  defp close_cycle(path, ref) do
    path
    |> Enum.drop_while(&(&1 != ref))
    |> then(&(&1 ++ [ref]))
  end

  defp validate_nsid(id) do
    case Nsid.parse(id) do
      {:ok, %Nsid{value: ^id}} -> :ok
      {:error, _reason} -> {:error, {:invalid_lexicon_id, id}}
    end
  end

  defp validate_defs_count(id, defs, limits) do
    cond do
      map_size(defs) == 0 ->
        {:error, {:missing_definitions, id}}

      map_size(defs) > limits[:max_definitions_per_document] ->
        {:error, {:loader_limit_exceeded, :max_definitions_per_document}}

      true ->
        :ok
    end
  end

  defp validate_definitions(%{"id" => id}, defs, limits) do
    Enum.reduce_while(defs, :ok, fn {name, schema}, :ok ->
      with :ok <- validate_definition_name(id, name),
           :ok <- validate_schema(schema, id, "#{id}##{name}", 0, limits) do
        {:cont, :ok}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp validate_definition_name(_id, name) when is_binary(name) and name != "", do: :ok
  defp validate_definition_name(id, name), do: {:error, {:invalid_definition_name, id, name}}

  defp validate_schema(schema, id, path, depth, limits) do
    if depth > limits[:max_schema_depth] do
      {:error, {:loader_limit_exceeded, :max_schema_depth, path}}
    else
      validate_schema_type(schema, id, path, depth, limits)
    end
  end

  defp validate_schema_type(%{"type" => type} = schema, id, path, depth, limits) when is_binary(type) do
    cond do
      not MapSet.member?(@schema_types, type) ->
        {:error, {:unsupported_schema_type, path, type}}

      type == "record" ->
        validate_record_schema(schema, id, path, depth, limits)

      type in ["query", "procedure"] ->
        validate_xrpc_schema(schema, id, path, depth, limits)

      type == "subscription" ->
        validate_subscription_schema(schema, id, path, depth, limits)

      type == "object" ->
        validate_object_schema(schema, id, path, depth, limits)

      type == "params" ->
        validate_object_schema(schema, id, path, depth, limits)

      type == "array" ->
        validate_array_schema(schema, id, path, depth, limits)

      type == "ref" ->
        validate_ref_schema(schema, id, path)

      type == "union" ->
        validate_union_schema(schema, id, path)

      true ->
        validate_primitive_schema(schema, path)
    end
  end

  defp validate_schema_type(_schema, _id, path, _depth, _limits), do: {:error, {:invalid_schema, path}}

  defp validate_record_schema(%{"record" => record} = schema, id, path, depth, limits) when is_map(record) do
    with :ok <- validate_optional_key(schema, path) do
      validate_schema(record, id, path <> ".record", depth + 1, limits)
    end
  end

  defp validate_record_schema(_schema, _id, path, _depth, _limits), do: {:error, {:invalid_schema, path}}

  defp validate_xrpc_schema(schema, id, path, depth, limits) do
    with :ok <- validate_optional_parameters_schema(schema, id, path, depth, limits),
         :ok <- validate_optional_io_schema(schema, "input", id, path, depth, limits),
         :ok <- validate_optional_io_schema(schema, "output", id, path, depth, limits) do
      :ok
    end
  end

  defp validate_subscription_schema(schema, id, path, depth, limits) do
    validate_optional_io_schema(schema, "message", id, path, depth, limits)
  end

  defp validate_object_schema(schema, id, path, depth, limits) do
    with :ok <- validate_string_list(Map.get(schema, "required", []), path <> ".required"),
         :ok <- validate_string_list(Map.get(schema, "nullable", []), path <> ".nullable"),
         {:ok, properties} <- validate_optional_map(schema, "properties", path),
         :ok <- validate_property_schemas(properties, id, path, depth, limits) do
      :ok
    end
  end

  defp validate_array_schema(%{"items" => items}, id, path, depth, limits) when is_map(items),
    do: validate_schema(items, id, path <> ".items", depth + 1, limits)

  defp validate_array_schema(_schema, _id, path, _depth, _limits), do: {:error, {:invalid_schema, path}}

  defp validate_optional_parameters_schema(%{"parameters" => parameters}, id, path, depth, limits)
       when is_map(parameters),
       do: validate_schema(parameters, id, path <> ".parameters", depth + 1, limits)

  defp validate_optional_parameters_schema(%{"parameters" => _parameters}, _id, path, _depth, _limits),
    do: {:error, {:invalid_schema, path <> ".parameters"}}

  defp validate_optional_parameters_schema(_schema, _id, _path, _depth, _limits), do: :ok

  defp validate_optional_io_schema(schema, key, id, path, depth, limits) do
    case Map.get(schema, key) do
      nil ->
        :ok

      %{"schema" => nested_schema} when is_map(nested_schema) ->
        validate_schema(nested_schema, id, path <> "." <> key <> ".schema", depth + 1, limits)

      %{} ->
        :ok

      _value ->
        {:error, {:invalid_schema, path <> "." <> key}}
    end
  end

  defp validate_ref_schema(%{"ref" => ref}, id, path) when is_binary(ref),
    do: validate_ref(ref, id, path)

  defp validate_ref_schema(_schema, _id, path), do: {:error, {:invalid_schema, path}}

  defp validate_union_schema(%{"refs" => refs}, id, path) when is_list(refs) and refs != [] do
    with :ok <- validate_ref_list(refs, id, path <> ".refs") do
      refs
      |> Enum.map(&normalize_ref(&1, id))
      |> duplicates()
      |> case do
        [] -> :ok
        duplicate_refs -> {:error, {:duplicate_refs, path, duplicate_refs}}
      end
    end
  end

  defp validate_union_schema(_schema, _id, path), do: {:error, {:invalid_schema, path}}

  defp validate_primitive_schema(schema, path) do
    with :ok <- validate_optional_string_list(schema, "knownValues", path),
         :ok <- validate_optional_string_list(schema, "enum", path),
         :ok <- validate_optional_integer(schema, "minimum", path),
         :ok <- validate_optional_integer(schema, "maximum", path),
         :ok <- validate_optional_integer(schema, "minLength", path),
         :ok <- validate_optional_integer(schema, "maxLength", path),
         :ok <- validate_optional_integer(schema, "minGraphemes", path),
         :ok <- validate_optional_integer(schema, "maxGraphemes", path) do
      :ok
    end
  end

  defp validate_optional_key(%{"key" => "any"}, _path), do: :ok
  defp validate_optional_key(%{"key" => "tid"}, _path), do: :ok
  defp validate_optional_key(%{"key" => "nsid"}, _path), do: :ok
  defp validate_optional_key(%{"key" => "literal:" <> literal}, _path) when literal != "", do: :ok
  defp validate_optional_key(%{"key" => key}, path), do: {:error, {:unsupported_record_key_type, path, key}}
  defp validate_optional_key(_schema, _path), do: :ok

  defp validate_optional_map(schema, key, path) do
    case Map.get(schema, key, %{}) do
      value when is_map(value) -> {:ok, value}
      _value -> {:error, {:invalid_schema, path <> "." <> key}}
    end
  end

  defp validate_property_schemas(properties, id, path, depth, limits) do
    Enum.reduce_while(properties, :ok, fn {name, property_schema}, :ok ->
      if is_binary(name) and name != "" do
        case validate_schema(property_schema, id, path <> ".properties." <> name, depth + 1, limits) do
          :ok -> {:cont, :ok}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      else
        {:halt, {:error, {:invalid_property_name, path, name}}}
      end
    end)
  end

  defp validate_ref_list(refs, id, path) do
    Enum.reduce_while(refs, :ok, fn ref, :ok ->
      case validate_ref(ref, id, path) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp validate_ref(ref, id, path) when is_binary(ref) do
    case normalize_ref(ref, id) do
      nil -> {:error, {:invalid_ref, path, ref}}
      _normalized_ref -> :ok
    end
  end

  defp validate_ref(ref, _id, path), do: {:error, {:invalid_ref, path, ref}}

  defp validate_optional_string_list(schema, key, path) do
    case Map.get(schema, key) do
      nil -> :ok
      value -> validate_string_list(value, path <> "." <> key)
    end
  end

  defp validate_string_list(value, _path) when is_list(value) do
    if Enum.all?(value, &is_binary/1), do: :ok, else: {:error, :invalid_lexicon_document}
  end

  defp validate_string_list(_value, path), do: {:error, {:invalid_schema, path}}

  defp validate_optional_integer(schema, key, path) do
    case Map.get(schema, key) do
      nil -> :ok
      value when is_integer(value) -> :ok
      _value -> {:error, {:invalid_schema, path <> "." <> key}}
    end
  end

  defp collect_refs(%{"type" => "ref", "ref" => ref}, id) when is_binary(ref), do: [normalize_ref(ref, id)]

  defp collect_refs(%{"type" => "union", "refs" => refs}, id) when is_list(refs) do
    refs
    |> Enum.filter(&is_binary/1)
    |> Enum.map(&normalize_ref(&1, id))
  end

  defp collect_refs(%{"type" => "record", "record" => record}, id) when is_map(record), do: collect_refs(record, id)

  defp collect_refs(%{"type" => type} = schema, id) when type in ["query", "procedure"] do
    ["parameters", "input", "output"]
    |> Enum.flat_map(fn key -> collect_io_refs(Map.get(schema, key), id) end)
  end

  defp collect_refs(%{"type" => "subscription"} = schema, id), do: collect_io_refs(Map.get(schema, "message"), id)

  defp collect_refs(%{"type" => "object", "properties" => properties}, id) when is_map(properties) do
    Enum.flat_map(properties, fn {_name, schema} -> collect_refs(schema, id) end)
  end

  defp collect_refs(%{"type" => "array", "items" => items}, id) when is_map(items), do: collect_refs(items, id)

  defp collect_refs(_schema, _id), do: []

  defp collect_io_refs(%{"schema" => schema}, id) when is_map(schema), do: collect_refs(schema, id)
  defp collect_io_refs(%{"type" => _type} = schema, id), do: collect_refs(schema, id)
  defp collect_io_refs(_schema, _id), do: []

  defp normalize_ref_string("#" <> name) when name != "", do: "#" <> name

  defp normalize_ref_string(ref) do
    case String.split(ref, "#", parts: 2) do
      [id] ->
        if valid_nsid_string?(id), do: id <> "#main"

      [id, name] ->
        if valid_nsid_string?(id) and name != "", do: id <> "#" <> name
    end
  end

  defp build_ref(id, name) do
    if valid_nsid_string?(id) and is_binary(name) and name != "" do
      id <> "#" <> name
    end
  end

  defp valid_nsid_string?(id) do
    match?({:ok, %Nsid{value: ^id}}, Nsid.parse(id))
  end

  defp duplicates(values) do
    values
    |> Enum.reject(&is_nil/1)
    |> Enum.frequencies()
    |> Enum.filter(fn {_value, count} -> count > 1 end)
    |> Enum.map(fn {value, _count} -> value end)
    |> Enum.sort()
  end
end
