defmodule Tempest.Lexicon.Validator do
  @moduledoc """
  Generic Lexicon schema validator for repository records.
  """

  alias Tempest.Lexicon.{KnownRecords, Registry}
  alias Tempest.RepoCore.{AtUri, Cid, Did, Handle, Nsid, RecordKey, Tid}

  @max_depth 64

  def validate_record(collection, rkey, record, opts \\ [])

  def validate_record(collection, rkey, record, opts) when is_binary(collection) and is_binary(rkey) do
    validate_schema? = Keyword.get(opts, :validate_schema?, true)
    require_schema? = Keyword.get(opts, :require_schema?, false)

    with :ok <- validate_record_type(collection, record) do
      if validate_schema? do
        case Registry.fetch_record(collection) do
          {:ok, document, definition} ->
            with :ok <- validate_record_key(Map.get(definition, "key"), rkey) do
              schema = Map.fetch!(definition, "record")

              with :ok <- validate_value(record, schema, document, collection, 0) do
                {:ok, :valid}
              end
            end

          {:error, :unknown_lexicon} ->
            cond do
              KnownRecords.known?(collection) -> {:ok, :valid}
              not require_schema? -> {:ok, :unknown}
              true -> {:error, :unknown_lexicon}
            end

          {:error, reason} ->
            {:error, reason}
        end
      else
        {:ok, :unknown}
      end
    end
  end

  def validate_record(_collection, _rkey, _record, _opts), do: {:error, :invalid_record}

  defp validate_record_type(collection, %{"$type" => collection}), do: :ok
  defp validate_record_type(_collection, %{"$type" => type}) when is_binary(type), do: {:error, :record_type_mismatch}
  defp validate_record_type(_collection, _record), do: {:error, :missing_record_type}

  defp validate_record_key("literal:" <> literal, literal), do: :ok
  defp validate_record_key("literal:" <> literal, _rkey), do: {:error, {:invalid_record_key, "literal:" <> literal}}
  defp validate_record_key("tid", rkey), do: if(Tid.valid?(rkey), do: :ok, else: {:error, {:invalid_record_key, "tid"}})

  defp validate_record_key("nsid", rkey),
    do: if(match?({:ok, _nsid}, Nsid.parse(rkey)), do: :ok, else: {:error, {:invalid_record_key, "nsid"}})

  defp validate_record_key("any", _rkey), do: :ok
  defp validate_record_key(nil, _rkey), do: :ok
  defp validate_record_key(key_type, _rkey), do: {:error, {:unsupported_record_key_type, key_type}}

  defp validate_value(_value, _schema, _document, _path, depth) when depth > @max_depth,
    do: {:error, :max_depth_exceeded}

  defp validate_value(value, %{"type" => "object"} = schema, document, path, depth) do
    with :ok <- ensure_map(value, path),
         :ok <- validate_required(value, Map.get(schema, "required", []), path),
         :ok <- validate_object_fields(value, schema, document, path, depth) do
      :ok
    end
  end

  defp validate_value(value, %{"type" => "array"} = schema, document, path, depth) do
    with :ok <- ensure_list(value, path),
         :ok <- validate_count(value, schema, path),
         {:ok, item_schema} <- fetch_item_schema(schema, path) do
      value
      |> Enum.with_index()
      |> Enum.reduce_while(:ok, fn {item, index}, :ok ->
        item_path = "#{path}[#{index}]"

        case validate_value(item, item_schema, document, item_path, depth + 1) do
          :ok -> {:cont, :ok}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
    end
  end

  defp validate_value(value, %{"type" => "string"} = schema, _document, path, _depth) do
    with :ok <- ensure_string(value, path),
         :ok <- validate_string_constraints(value, schema, path),
         :ok <- validate_string_format(value, Map.get(schema, "format"), path),
         :ok <- validate_enum(value, schema, path) do
      :ok
    end
  end

  defp validate_value(value, %{"type" => "integer"} = schema, _document, path, _depth) do
    with :ok <- ensure_integer(value, path),
         :ok <- validate_integer_constraints(value, schema, path),
         :ok <- validate_enum(value, schema, path) do
      :ok
    end
  end

  defp validate_value(value, %{"type" => "boolean"}, _document, path, _depth), do: ensure_boolean(value, path)

  defp validate_value(value, %{"type" => "bytes"} = schema, _document, path, _depth) do
    with :ok <- ensure_bytes_json(value, path) do
      encoded = Map.fetch!(value, "$bytes")
      decoded = Base.decode64(encoded)

      with {:ok, bytes} <- decoded do
        validate_byte_constraints(bytes, schema, path)
      else
        :error -> {:error, {:invalid_field, path}}
      end
    end
  end

  defp validate_value(value, %{"type" => "cid-link"}, _document, path, _depth) do
    case value do
      %{"$link" => cid} -> validate_string_format(cid, "cid", path)
      _value -> {:error, {:invalid_field, path}}
    end
  end

  defp validate_value(value, %{"type" => "blob"} = schema, _document, path, _depth) do
    with :ok <- ensure_map(value, path),
         :ok <- validate_optional_blob_size(value, schema, path),
         :ok <- validate_optional_blob_mime(value, schema, path) do
      :ok
    end
  end

  defp validate_value(_value, %{"type" => "unknown"}, _document, _path, _depth), do: :ok

  defp validate_value(value, %{"type" => "ref", "ref" => ref}, document, path, depth) do
    with {:ok, ref_document, definition} <- Registry.fetch_definition(ref, Map.fetch!(document, "id")) do
      validate_definition(value, definition, ref_document, path, depth + 1)
    end
  end

  defp validate_value(value, %{"type" => "union"} = schema, document, path, depth) do
    with :ok <- ensure_map(value, path),
         {:ok, type} <- fetch_type(value, path),
         {:ok, ref} <- union_ref(type, Map.get(schema, "refs", []), Map.fetch!(document, "id"), path),
         {:ok, ref_document, definition} <- Registry.fetch_definition(ref, Map.fetch!(document, "id")) do
      validate_definition(value, definition, ref_document, path, depth + 1)
    end
  end

  defp validate_value(_value, schema, _document, path, _depth),
    do: {:error, {:unsupported_schema_type, path, Map.get(schema, "type")}}

  defp validate_definition(value, %{"type" => "record"} = definition, document, path, depth) do
    with :ok <- validate_record_type(Map.fetch!(document, "id"), value) do
      validate_value(value, Map.fetch!(definition, "record"), document, path, depth + 1)
    end
  end

  defp validate_definition(value, definition, document, path, depth) do
    validate_value(value, definition, document, path, depth + 1)
  end

  defp validate_required(value, required, path) do
    Enum.reduce_while(required, :ok, fn field, :ok ->
      if Map.has_key?(value, field) and not is_nil(Map.get(value, field)) do
        {:cont, :ok}
      else
        {:halt, {:error, {:missing_field, join_path(path, field)}}}
      end
    end)
  end

  defp validate_object_fields(value, schema, document, path, depth) do
    properties = Map.get(schema, "properties", %{})
    nullable = Map.get(schema, "nullable", [])

    Enum.reduce_while(value, :ok, fn {field, field_value}, :ok ->
      cond do
        field == "$type" ->
          {:cont, :ok}

        is_nil(field_value) and field in nullable ->
          {:cont, :ok}

        is_nil(field_value) ->
          {:halt, {:error, {:invalid_field, join_path(path, field)}}}

        field_schema = Map.get(properties, field) ->
          case validate_value(field_value, field_schema, document, join_path(path, field), depth + 1) do
            :ok -> {:cont, :ok}
            {:error, reason} -> {:halt, {:error, reason}}
          end

        true ->
          {:halt, {:error, {:unknown_field, join_path(path, field)}}}
      end
    end)
  end

  defp fetch_item_schema(%{"items" => item_schema}, _path) when is_map(item_schema), do: {:ok, item_schema}
  defp fetch_item_schema(_schema, path), do: {:error, {:invalid_schema, path}}

  defp validate_count(value, schema, path) do
    min = Map.get(schema, "minLength")
    max = Map.get(schema, "maxLength")
    count = length(value)

    cond do
      is_integer(min) and count < min -> {:error, {:field_too_short, path}}
      is_integer(max) and count > max -> {:error, {:field_too_long, path}}
      true -> :ok
    end
  end

  defp validate_string_constraints(value, schema, path) do
    min_bytes = Map.get(schema, "minLength")
    max_bytes = Map.get(schema, "maxLength")
    min_graphemes = Map.get(schema, "minGraphemes")
    max_graphemes = Map.get(schema, "maxGraphemes")

    cond do
      is_integer(min_bytes) and byte_size(value) < min_bytes -> {:error, {:field_too_short, path}}
      is_integer(max_bytes) and byte_size(value) > max_bytes -> {:error, {:field_too_long, path}}
      is_integer(min_graphemes) and String.length(value) < min_graphemes -> {:error, {:field_too_short, path}}
      is_integer(max_graphemes) and String.length(value) > max_graphemes -> {:error, {:field_too_long, path}}
      true -> :ok
    end
  end

  defp validate_integer_constraints(value, schema, path) do
    min = Map.get(schema, "minimum")
    max = Map.get(schema, "maximum")

    cond do
      is_integer(min) and value < min -> {:error, {:field_too_small, path}}
      is_integer(max) and value > max -> {:error, {:field_too_large, path}}
      true -> :ok
    end
  end

  defp validate_byte_constraints(value, schema, path) do
    min = Map.get(schema, "minLength")
    max = Map.get(schema, "maxLength")

    cond do
      is_integer(min) and byte_size(value) < min -> {:error, {:field_too_short, path}}
      is_integer(max) and byte_size(value) > max -> {:error, {:field_too_long, path}}
      true -> :ok
    end
  end

  defp validate_enum(value, %{"enum" => enum}, path) when is_list(enum) do
    if value in enum, do: :ok, else: {:error, {:invalid_field, path}}
  end

  defp validate_enum(_value, _schema, _path), do: :ok

  defp validate_string_format(value, nil, _path), do: if(String.valid?(value), do: :ok, else: {:error, :invalid_string})
  defp validate_string_format(value, "cid", path), do: parse_format(value, path, &Cid.parse/1)
  defp validate_string_format(value, "at-uri", path), do: parse_format(value, path, &AtUri.parse/1)
  defp validate_string_format(value, "did", path), do: parse_format(value, path, &Did.parse/1)
  defp validate_string_format(value, "handle", path), do: parse_format(value, path, &Handle.parse/1)
  defp validate_string_format(value, "nsid", path), do: parse_format(value, path, &Nsid.parse/1)
  defp validate_string_format(value, "record-key", path), do: parse_format(value, path, &RecordKey.parse/1)
  defp validate_string_format(value, "tid", path), do: parse_format(value, path, &Tid.parse/1)

  defp validate_string_format(value, "datetime", path) do
    case DateTime.from_iso8601(value) do
      {:ok, _datetime, _offset} -> :ok
      {:error, _reason} -> {:error, {:invalid_field, path}}
    end
  end

  defp validate_string_format(value, "uri", path) do
    uri = URI.parse(value)

    if is_binary(uri.scheme) and uri.scheme != "" do
      :ok
    else
      {:error, {:invalid_field, path}}
    end
  end

  defp validate_string_format(value, _format, _path),
    do: if(String.valid?(value), do: :ok, else: {:error, :invalid_string})

  defp parse_format(value, path, parser) do
    case parser.(value) do
      {:ok, _parsed} -> :ok
      {:error, _reason} -> {:error, {:invalid_field, path}}
    end
  end

  defp validate_optional_blob_size(value, %{"maxSize" => max_size}, path) when is_integer(max_size) do
    case Map.get(value, "size") do
      nil -> :ok
      size when is_integer(size) and size <= max_size -> :ok
      _size -> {:error, {:invalid_field, join_path(path, "size")}}
    end
  end

  defp validate_optional_blob_size(_value, _schema, _path), do: :ok

  defp validate_optional_blob_mime(value, %{"accept" => accept}, path) when is_list(accept) do
    case Map.get(value, "mimeType") do
      nil ->
        :ok

      mime_type when is_binary(mime_type) ->
        if(accepted_mime_type?(mime_type, accept),
          do: :ok,
          else: {:error, {:invalid_field, join_path(path, "mimeType")}}
        )

      _mime_type ->
        {:error, {:invalid_field, join_path(path, "mimeType")}}
    end
  end

  defp validate_optional_blob_mime(_value, _schema, _path), do: :ok

  defp accepted_mime_type?(_mime_type, ["*/*" | _rest]), do: true

  defp accepted_mime_type?(mime_type, [accepted | rest]) do
    cond do
      String.ends_with?(accepted, "/*") ->
        prefix = String.trim_trailing(accepted, "*")
        String.starts_with?(mime_type, prefix) or accepted_mime_type?(mime_type, rest)

      mime_type == accepted ->
        true

      true ->
        accepted_mime_type?(mime_type, rest)
    end
  end

  defp accepted_mime_type?(_mime_type, []), do: false

  defp fetch_type(%{"$type" => type}, _path) when is_binary(type), do: {:ok, type}
  defp fetch_type(_value, path), do: {:error, {:missing_field, join_path(path, "$type")}}

  defp union_ref(type, refs, current_id, path) do
    Enum.find_value(refs, {:error, {:invalid_field, path}}, fn ref ->
      if Registry.normalize_ref(ref, current_id) == type do
        {:ok, ref}
      end
    end)
  end

  defp ensure_map(value, _path) when is_map(value), do: :ok
  defp ensure_map(_value, path), do: {:error, {:invalid_field, path}}

  defp ensure_list(value, _path) when is_list(value), do: :ok
  defp ensure_list(_value, path), do: {:error, {:invalid_field, path}}

  defp ensure_string(value, _path) when is_binary(value), do: :ok
  defp ensure_string(_value, path), do: {:error, {:invalid_field, path}}

  defp ensure_integer(value, _path) when is_integer(value), do: :ok
  defp ensure_integer(_value, path), do: {:error, {:invalid_field, path}}

  defp ensure_boolean(value, _path) when is_boolean(value), do: :ok
  defp ensure_boolean(_value, path), do: {:error, {:invalid_field, path}}

  defp ensure_bytes_json(%{"$bytes" => value}, path) when is_binary(value), do: validate_string_format(value, nil, path)
  defp ensure_bytes_json(_value, path), do: {:error, {:invalid_field, path}}

  defp join_path("$", field), do: field
  defp join_path(path, field), do: path <> "." <> field
end
