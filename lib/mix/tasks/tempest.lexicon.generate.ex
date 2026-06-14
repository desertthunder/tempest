defmodule Mix.Tasks.Tempest.Lexicon.Generate do
  @shortdoc "Generates bundled Lexicon schema data"

  @moduledoc """
  Generates `Tempest.Lexicon.Bundled` from a pinned Lexicon directory.

      mix tempest.lexicon.generate --source ../atproto/lexicons --commit <commit>

  Options:

    * `--source` - required file or directory containing Lexicon JSON files.
    * `--commit` - required source commit or immutable source identifier.
    * `--source-repo` - source repository label. Defaults to `atproto`.
    * `--out` - output file. Defaults to `lib/tempest/lexicon/bundled.ex`.
    * `--generated-at` - ISO8601 timestamp. Defaults to current UTC time.
    * `--include` - comma-separated document ids to include. Dependencies reached
      through local refs are included automatically.
    * `--namespace` - comma-separated document id prefixes to include. This can
      be used instead of enumerating every document id, for example
      `--namespace app.bsky.feed,com.atproto.repo`.

  Operator update workflow:

    1. Check out or vendor the desired `bluesky-social/atproto` revision.
    2. Run this task with `--source` pointing at that checkout's `lexicons/`
       directory and `--commit` set to the exact source commit.
    3. Review the generated manifest in `Tempest.Lexicon.Bundled`; it records
       source repo, commit, generation time, document count, and document ids.
    4. Run `mix test test/tempest/lexicon` or `mix precommit` before deploying.

  Tempest's compatibility tests intentionally target official `com.atproto.*`
  Lexicons that match this PDS implementation, not official `app.bsky` profile,
  post, or follow record schemas.
  """

  use Mix.Task

  alias Tempest.Lexicon.Document
  alias Tempest.Lexicon.LocalProvider

  @requirements ["app.config"]

  @impl true
  def run(args) do
    {opts, _rest, invalid} =
      OptionParser.parse(args,
        strict: [
          source: :string,
          commit: :string,
          source_repo: :string,
          out: :string,
          generated_at: :string,
          include: :string,
          namespace: :string
        ],
        aliases: [s: :source, c: :commit, o: :out]
      )

    if invalid != [] do
      Mix.raise("invalid options: #{inspect(invalid)}")
    end

    source = Keyword.get(opts, :source) || Mix.raise("--source is required")
    commit = Keyword.get(opts, :commit) || Mix.raise("--commit is required")
    output = Keyword.get(opts, :out, "lib/tempest/lexicon/bundled.ex")
    source_repo = Keyword.get(opts, :source_repo, "atproto")
    generated_at = Keyword.get(opts, :generated_at, generated_at())

    with {:ok, documents, _manifest} <- LocalProvider.load(paths: [source]),
         documents = select_documents(documents, Keyword.get(opts, :include), Keyword.get(opts, :namespace)),
         :ok <- Document.validate_documents(documents) do
      File.mkdir_p!(Path.dirname(output))
      File.write!(output, module_source(documents, source_repo, commit, generated_at))
      Mix.shell().info("Generated #{output} with #{length(documents)} Lexicon document(s)")
    else
      {:error, reason} -> Mix.raise("failed to generate bundled Lexicons: #{inspect(reason)}")
    end
  end

  defp select_documents(documents, nil, nil), do: sort_documents(documents)

  defp select_documents(documents, include, namespace) do
    ids =
      documents
      |> included_document_ids(include)
      |> namespace_document_ids(namespace)
      |> Enum.uniq()

    by_id = Map.new(documents, &{Map.fetch!(&1, "id"), &1})

    ids
    |> expand_dependencies(by_id, %{})
    |> Map.keys()
    |> Enum.map(&Map.fetch!(by_id, &1))
    |> sort_documents()
  end

  defp included_document_ids(documents, nil), do: Enum.map(documents, &Map.fetch!(&1, "id"))

  defp included_document_ids(_documents, include) do
    include
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp namespace_document_ids(ids, nil), do: ids

  defp namespace_document_ids(ids, namespace) do
    namespaces =
      namespace
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    Enum.filter(ids, fn id -> Enum.any?(namespaces, &(id == &1 or String.starts_with?(id, &1 <> "."))) end)
  end

  defp expand_dependencies(ids, by_id, seen) do
    ids
    |> Enum.reduce(seen, fn id, seen ->
      if Map.has_key?(seen, id) do
        seen
      else
        document = Map.fetch!(by_id, id)

        dependencies =
          document
          |> Document.referenced_definition_refs()
          |> Enum.map(fn ref -> ref |> String.split("#", parts: 2) |> List.first() end)
          |> Enum.filter(&Map.has_key?(by_id, &1))

        expand_dependencies(dependencies, by_id, Map.put(seen, id, true))
      end
    end)
  end

  defp sort_documents(documents), do: Enum.sort_by(documents, &Map.fetch!(&1, "id"))

  defp module_source(documents, source_repo, commit, generated_at) do
    manifest = %{
      "source_repo" => source_repo,
      "source_commit" => commit,
      "generated_at" => generated_at,
      "document_count" => length(documents),
      "document_ids" => Enum.map(documents, &Map.fetch!(&1, "id"))
    }

    """
    defmodule Tempest.Lexicon.Bundled do
      @moduledoc \"\"\"
      Bundled generated Lexicon documents.

      Regenerate with:

          mix tempest.lexicon.generate --source <path-to-lexicons> --commit <commit>
      \"\"\"

      @behaviour Tempest.Lexicon.Provider

      @manifest #{inspect(manifest, pretty: true, limit: :infinity, printable_limit: :infinity)}

      @documents #{inspect(documents, pretty: true, limit: :infinity, printable_limit: :infinity)}

      @impl true
      def load(_opts), do: {:ok, @documents, @manifest}

      def documents, do: @documents
      def manifest, do: @manifest
    end
    """
  end

  defp generated_at do
    DateTime.utc_now()
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
  end
end
