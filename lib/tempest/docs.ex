defmodule Tempest.Docs do
  @moduledoc """
  Reference documentation loaded from the fixed `docs/reference/` manifest.

  The public API accepts slugs, never paths. Markdown content is trusted local
  project documentation, but file lookup remains constrained to the manifest.
  """

  @enforce_keys [:slug, :path, :title]
  defstruct [:slug, :path, :title, :updated, :markdown, :html]

  @type document :: %__MODULE__{
          slug: String.t(),
          path: String.t(),
          title: String.t(),
          updated: String.t() | nil,
          markdown: String.t() | nil,
          html: String.t() | nil
        }

  @documents [
    %{slug: "reference", path: "README.md", title: "Reference Documentation"},
    %{slug: "account-migration", path: "account-migration.md", title: "Account Migration"},
    %{slug: "admin-operations", path: "admin-operations.md", title: "Admin and Operator Operations"},
    %{slug: "architecture", path: "architecture.md", title: "Architecture"},
    %{slug: "blobs", path: "blobs.md", title: "Blobs"},
    %{slug: "budget", path: "budget.md", title: "Budget"},
    %{slug: "car-drisl", path: "car-drisl.md", title: "CAR and DRISL"},
    %{slug: "deployment", path: "deployment.md", title: "Deployment Guide"},
    %{slug: "deployment-observability", path: "deployment-observability.md", title: "Deployment and Observability"},
    %{slug: "endpoints", path: "endpoints.md", title: "Endpoints"},
    %{slug: "identity-handles", path: "identity-handles.md", title: "Identity and Handles"},
    %{slug: "identity-troubleshooting", path: "identity-troubleshooting.md", title: "Identity Troubleshooting"},
    %{slug: "interop-testing", path: "interop-testing.md", title: "Interop and Integration Testing"},
    %{slug: "lexicon-schemas", path: "lexicon-schemas.md", title: "Lexicon Schemas"},
    %{slug: "migration-lifecycle", path: "migration-lifecycle.md", title: "Migration and Account Lifecycle"},
    %{slug: "pds-compatibility", path: "pds-compatibility.md", title: "PDS Compatibility Matrix"},
    %{slug: "record-apis", path: "record-apis.md", title: "Record APIs"},
    %{slug: "release", path: "release.md", title: "Initial Release Readiness"},
    %{slug: "repo-core", path: "repo-core.md", title: "Repository Core"},
    %{slug: "security-oauth", path: "security-oauth.md", title: "Security, OAuth, and Delegated Access"},
    %{slug: "storage-sqlite", path: "storage-sqlite.md", title: "SQLite Storage"},
    %{slug: "sync-firehose", path: "sync-firehose.md", title: "Sync and Firehose"},
    %{slug: "tokens", path: "tokens.md", title: "Tokens"},
    %{slug: "public-stats-dashboard", path: "public-stats-dashboard.md", title: "Public Stats Dashboard"},
    %{slug: "xrpc", path: "xrpc.md", title: "XRPC HTTP Surface"}
  ]

  @reference_source_root Path.expand("../../docs/reference", __DIR__)

  for entry <- @documents do
    @external_resource Path.join(@reference_source_root, entry.path)
  end

  @embedded_markdown Map.new(@documents, fn entry ->
                       {entry.path, File.read!(Path.join(@reference_source_root, entry.path))}
                     end)

  @markdown_options [
    extension: [
      autolink: true,
      strikethrough: true,
      table: true
    ]
  ]

  @doc "Returns the fixed reference document manifest in display order."
  @spec list_documents() :: [document()]
  def list_documents do
    Enum.map(@documents, &manifest_document/1)
  end

  @doc "Fetches and renders a known reference document by slug."
  @spec fetch_document(String.t()) :: {:ok, document()} | {:error, :not_found}
  def fetch_document(slug) when is_binary(slug) do
    with {:ok, entry} <- lookup_manifest(slug),
         {:ok, markdown} <- read_manifest_file(entry) do
      {frontmatter, body} = split_frontmatter(markdown)
      title = Map.get(frontmatter, "title") || entry.title
      updated = Map.get(frontmatter, "updated")
      rewritten_body = rewrite_reference_links(body, entry)
      html = MDEx.to_html!(rewritten_body, @markdown_options)

      {:ok,
       %__MODULE__{
         slug: entry.slug,
         path: entry.path,
         title: title,
         updated: updated,
         markdown: rewritten_body,
         html: html
       }}
    else
      _ -> {:error, :not_found}
    end
  end

  @doc "Returns a known reference document by slug or raises `Ecto.NoResultsError`."
  @spec get_document!(String.t()) :: document()
  def get_document!(slug) do
    case fetch_document(slug) do
      {:ok, document} -> document
      {:error, :not_found} -> raise Ecto.NoResultsError, queryable: __MODULE__
    end
  end

  @doc "Returns the viewer route for a known document slug."
  @spec document_path(document() | String.t()) :: String.t()
  def document_path(%__MODULE__{slug: slug}), do: document_path(slug)
  def document_path("reference"), do: "/docs"
  def document_path(slug) when is_binary(slug), do: "/docs/" <> slug

  @doc "Returns previous and next manifest documents for a known slug."
  @spec adjacent_documents(String.t()) :: {document() | nil, document() | nil}
  def adjacent_documents(slug) when is_binary(slug) do
    documents = list_documents()
    index = Enum.find_index(documents, &(&1.slug == slug))

    if index do
      previous_document = if index > 0, do: Enum.at(documents, index - 1)

      {previous_document, Enum.at(documents, index + 1)}
    else
      {nil, nil}
    end
  end

  defp lookup_manifest(slug) do
    if valid_slug?(slug) do
      case Enum.find(@documents, &(&1.slug == slug)) do
        nil -> {:error, :not_found}
        entry -> {:ok, entry}
      end
    else
      {:error, :not_found}
    end
  end

  defp valid_slug?(slug), do: Regex.match?(~r/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/, slug)

  defp manifest_document(entry) do
    %__MODULE__{slug: entry.slug, path: entry.path, title: entry.title}
  end

  defp read_manifest_file(entry) do
    root = reference_root()
    path = Path.expand(entry.path, root)

    if inside_reference_root?(path, root) do
      case File.read(path) do
        {:ok, markdown} -> {:ok, markdown}
        {:error, _reason} -> embedded_manifest_file(entry)
      end
    else
      {:error, :not_found}
    end
  end

  defp embedded_manifest_file(entry) do
    case Map.fetch(@embedded_markdown, entry.path) do
      {:ok, markdown} -> {:ok, markdown}
      :error -> {:error, :not_found}
    end
  end

  defp reference_root do
    Path.expand("docs/reference", File.cwd!())
  end

  defp inside_reference_root?(path, root) do
    path == root or String.starts_with?(path, root <> "/")
  end

  defp split_frontmatter("---\n" <> rest) do
    case :binary.split(rest, "\n---\n") do
      [frontmatter, body] -> {parse_frontmatter(frontmatter), body}
      _ -> {%{}, "---\n" <> rest}
    end
  end

  defp split_frontmatter(markdown), do: {%{}, markdown}

  defp parse_frontmatter(frontmatter) do
    frontmatter
    |> String.split("\n")
    |> Enum.reduce(%{}, fn line, acc ->
      case String.split(line, ":", parts: 2) do
        [key, value] when key in ["title", "updated"] -> Map.put(acc, key, String.trim(value))
        _ -> acc
      end
    end)
  end

  defp rewrite_reference_links(markdown, current_entry) do
    Regex.replace(~r/(!?)\[([^\]]+)\]\(([^)\s]+)(\s+(?:"[^"]*"|'[^']*'|\([^)]+\)))?\)/, markdown, fn
      full_match, "!", _text, _destination, _title ->
        full_match

      full_match, _bang, _text, destination, title ->
        rewrite_link_match(full_match, destination, title || "", current_entry)
    end)
  end

  defp rewrite_link_match(full_match, destination, title, current_entry) do
    case reference_destination(destination, current_entry) do
      {:ok, href} -> String.replace(full_match, "(" <> destination <> title <> ")", "(" <> href <> title <> ")")
      :error -> full_match
    end
  end

  defp reference_destination(destination, current_entry) do
    uri = URI.parse(destination)

    cond do
      uri.scheme || uri.host || String.starts_with?(destination, "#") ->
        :error

      uri.path && String.ends_with?(uri.path, ".md") ->
        resolve_reference_destination(uri, current_entry)

      true ->
        :error
    end
  end

  defp resolve_reference_destination(uri, current_entry) do
    root = reference_root()
    current_dir = Path.dirname(Path.expand(current_entry.path, root))
    path = Path.expand(uri.path, current_dir)

    with true <- inside_reference_root?(path, root),
         relative_path <- Path.relative_to(path, root),
         {:ok, entry} <- lookup_manifest_by_path(relative_path) do
      suffix =
        case uri.fragment do
          nil -> ""
          fragment -> "#" <> fragment
        end

      {:ok, document_path(entry.slug) <> suffix}
    else
      _ -> :error
    end
  end

  defp lookup_manifest_by_path(path) do
    case Enum.find(@documents, &(&1.path == path)) do
      nil -> {:error, :not_found}
      entry -> {:ok, entry}
    end
  end
end
