defmodule Tempest.Lexicon.LocalProvider do
  @moduledoc """
  Loads operator-configured Lexicon JSON files from local files or directories.
  """

  @behaviour Tempest.Lexicon.Provider

  @default_limits [
    max_files: 1_000,
    max_file_bytes: 1_000_000
  ]

  @impl true
  def load(opts) do
    paths = Keyword.get(opts, :paths, [])
    limits = Keyword.merge(@default_limits, opts)

    with {:ok, files} <- expand_files(paths, limits),
         {:ok, documents} <- read_documents(files, limits) do
      {:ok, documents, local_manifest(files, documents)}
    end
  end

  defp expand_files(paths, limits) when is_list(paths) do
    files =
      paths
      |> Enum.flat_map(&lexicon_files/1)
      |> Enum.uniq()
      |> Enum.sort()

    if length(files) <= limits[:max_files] do
      {:ok, files}
    else
      {:error, {:loader_limit_exceeded, :max_files}}
    end
  end

  defp expand_files(_paths, _limits), do: {:error, :invalid_lexicon_paths}

  defp read_documents(files, limits) do
    Enum.reduce_while(files, {:ok, []}, fn file, {:ok, documents} ->
      case read_document(file, limits) do
        {:ok, document} -> {:cont, {:ok, [document | documents]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, documents} -> {:ok, Enum.reverse(documents)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp read_document(file, limits) do
    with {:ok, stat} <- File.stat(file),
         :ok <- validate_file_size(file, stat.size, limits),
         {:ok, json} <- File.read(file),
         {:ok, document} <- Jason.decode(json) do
      if is_map(document), do: {:ok, document}, else: {:error, {:invalid_lexicon_json, file}}
    else
      {:error, %Jason.DecodeError{} = reason} -> {:error, {:invalid_lexicon_json, file, reason.data}}
      {:error, {:loader_limit_exceeded, _limit, _detail} = reason} -> {:error, reason}
      {:error, reason} -> {:error, {:lexicon_file_error, file, reason}}
    end
  end

  defp validate_file_size(file, size, limits) do
    if size <= limits[:max_file_bytes] do
      :ok
    else
      {:error, {:loader_limit_exceeded, :max_file_bytes, file}}
    end
  end

  defp lexicon_files(path) when is_binary(path) do
    cond do
      File.dir?(path) -> Path.wildcard(Path.join(path, "**/*.json"))
      File.regular?(path) -> [path]
      true -> []
    end
  end

  defp lexicon_files(_path), do: []

  defp local_manifest(files, documents) do
    %{
      "source" => "local",
      "file_count" => length(files),
      "document_count" => length(documents),
      "document_ids" => documents |> Enum.map(&Map.get(&1, "id")) |> Enum.sort()
    }
  end
end
