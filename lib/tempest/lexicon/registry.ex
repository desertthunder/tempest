defmodule Tempest.Lexicon.Registry do
  @moduledoc """
  Runtime lookup boundary for Lexicon documents.
  """

  @env_key __MODULE__

  def fetch(id) when is_binary(id) do
    case Map.fetch(documents(), id) do
      {:ok, document} -> {:ok, document}
      :error -> {:error, :unknown_lexicon}
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

  defp documents do
    config = Application.get_env(:tempest, @env_key, [])

    config
    |> Keyword.get(:documents, %{})
    |> normalize_documents()
    |> Map.merge(load_path_documents(Keyword.get(config, :paths, [])))
  end

  defp load_path_documents(paths) when is_list(paths) do
    paths
    |> Enum.flat_map(&lexicon_files/1)
    |> Enum.reduce(%{}, fn path, documents ->
      case File.read(path) do
        {:ok, json} ->
          case Jason.decode(json) do
            {:ok, %{"id" => id} = document} -> Map.put(documents, id, document)
            {:ok, _value} -> documents
            {:error, _reason} -> documents
          end

        {:error, _reason} ->
          documents
      end
    end)
  end

  defp load_path_documents(_paths), do: %{}

  defp lexicon_files(path) when is_binary(path) do
    cond do
      File.dir?(path) -> Path.wildcard(Path.join(path, "**/*.json"))
      File.regular?(path) -> [path]
      true -> []
    end
  end

  defp lexicon_files(_path), do: []

  defp normalize_documents(documents) when is_map(documents) do
    Map.new(documents, fn
      {id, %{"id" => id} = document} -> {id, document}
      {_key, %{"id" => id} = document} -> {id, document}
    end)
  end

  defp normalize_documents(documents) when is_list(documents) do
    Map.new(documents, fn %{"id" => id} = document -> {id, document} end)
  end

  defp normalize_documents(_documents), do: %{}

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
