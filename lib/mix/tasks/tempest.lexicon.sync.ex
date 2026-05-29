defmodule Mix.Tasks.Tempest.Lexicon.Sync do
  @shortdoc "Syncs pinned official atproto Lexicon JSON files"

  @moduledoc """
  Downloads Tempest's pinned official atproto Lexicon JSON set.

      mix tempest.lexicon.sync --commit <commit>

  Options:

    * `--commit` - required atproto git commit, tag, or immutable ref.
    * `--out` - destination directory. Defaults to `priv/lexicons/official`.
    * `--source-repo` - GitHub repository URL. Defaults to
      `https://github.com/bluesky-social/atproto`.
    * `--base-url` - raw file URL prefix for tests or mirrors. Defaults to the
      GitHub raw URL for `--source-repo` and `--commit`.
    * `--paths` - newline file with lexicon paths to sync. Defaults to the
      compatibility set used by Tempest.
    * `--generate` - regenerate `Tempest.Lexicon.Bundled` after syncing.
    * `--generated-at` - timestamp passed to the generator when `--generate` is set.
    * `--bundle-out` - generated module path when `--generate` is set.

  The default path set intentionally includes local PDS endpoints plus the
  private `app.bsky.actor` preference compatibility endpoints and their minimal
  official dependency closure as currently tracked by Tempest.
  """

  use Mix.Task

  alias Mix.Tasks.Tempest.Lexicon.Generate

  @requirements ["app.config"]

  @default_paths ~w(
    app/bsky/actor/defs.json
    app/bsky/actor/getPreferences.json
    app/bsky/actor/profile.json
    app/bsky/actor/putPreferences.json
    app/bsky/embed/defs.json
    app/bsky/embed/external.json
    app/bsky/embed/images.json
    app/bsky/embed/record.json
    app/bsky/embed/recordWithMedia.json
    app/bsky/embed/video.json
    app/bsky/feed/defs.json
    app/bsky/feed/postgate.json
    app/bsky/feed/threadgate.json
    app/bsky/graph/defs.json
    app/bsky/labeler/defs.json
    app/bsky/notification/defs.json
    app/bsky/richtext/facet.json
    com/atproto/identity/resolveHandle.json
    com/atproto/identity/updateHandle.json
    com/atproto/label/defs.json
    com/atproto/lexicon/schema.json
    com/atproto/moderation/defs.json
    com/atproto/repo/applyWrites.json
    com/atproto/repo/createRecord.json
    com/atproto/repo/defs.json
    com/atproto/repo/deleteRecord.json
    com/atproto/repo/describeRepo.json
    com/atproto/repo/getRecord.json
    com/atproto/repo/listRecords.json
    com/atproto/repo/putRecord.json
    com/atproto/repo/strongRef.json
    com/atproto/repo/uploadBlob.json
    com/atproto/server/createAccount.json
    com/atproto/server/createSession.json
    com/atproto/server/deleteSession.json
    com/atproto/server/describeServer.json
    com/atproto/server/getSession.json
    com/atproto/server/refreshSession.json
    com/atproto/sync/getBlob.json
    com/atproto/sync/getBlocks.json
    com/atproto/sync/getLatestCommit.json
    com/atproto/sync/getRecord.json
    com/atproto/sync/getRepo.json
    com/atproto/sync/getRepoStatus.json
    com/atproto/sync/listBlobs.json
    com/atproto/sync/listRepos.json
    com/atproto/sync/requestCrawl.json
    com/atproto/sync/subscribeRepos.json
  )

  @impl true
  def run(args) do
    {opts, _rest, invalid} =
      OptionParser.parse(args,
        strict: [
          commit: :string,
          out: :string,
          source_repo: :string,
          base_url: :string,
          paths: :string,
          generate: :boolean,
          generated_at: :string,
          bundle_out: :string
        ],
        aliases: [c: :commit, o: :out]
      )

    if invalid != [] do
      Mix.raise("invalid options: #{inspect(invalid)}")
    end

    commit = Keyword.get(opts, :commit) || Mix.raise("--commit is required")
    out = Keyword.get(opts, :out, "priv/lexicons/official")
    source_repo = Keyword.get(opts, :source_repo, "https://github.com/bluesky-social/atproto")
    base_url = Keyword.get(opts, :base_url, raw_base_url(source_repo, commit))
    paths = lexicon_paths(Keyword.get(opts, :paths))

    Enum.each(paths, &sync_path(base_url, out, &1))
    Mix.shell().info("Synced #{length(paths)} Lexicon document(s) to #{out}")

    if Keyword.get(opts, :generate, false) do
      generate_args = [
        "--source",
        out,
        "--commit",
        commit,
        "--source-repo",
        source_repo,
        "--out",
        Keyword.get(opts, :bundle_out, "lib/tempest/lexicon/bundled.ex")
      ]

      generate_args =
        case Keyword.get(opts, :generated_at) do
          nil -> generate_args
          generated_at -> generate_args ++ ["--generated-at", generated_at]
        end

      Generate.run(generate_args)
    end
  end

  defp raw_base_url("https://github.com/" <> repo, commit) do
    "https://raw.githubusercontent.com/" <> String.trim_trailing(repo, "/") <> "/" <> commit <> "/lexicons"
  end

  defp raw_base_url(source_repo, commit), do: String.trim_trailing(source_repo, "/") <> "/" <> commit <> "/lexicons"

  defp lexicon_paths(nil), do: @default_paths

  defp lexicon_paths(path_file) do
    path_file
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))
  end

  defp sync_path("file://" <> source, out, path) do
    source_path = Path.join(source, path)
    destination = Path.join(out, path)

    File.mkdir_p!(Path.dirname(destination))
    File.cp!(source_path, destination)
  end

  defp sync_path(base_url, out, path) do
    url = String.trim_trailing(base_url, "/") <> "/" <> path

    case Req.get(url: url, retry: false) do
      {:ok, %{status: 200, body: body}} ->
        destination = Path.join(out, path)
        File.mkdir_p!(Path.dirname(destination))
        File.write!(destination, body)

      {:ok, %{status: status}} ->
        Mix.raise("failed to fetch #{url}: HTTP #{status}")

      {:error, reason} ->
        Mix.raise("failed to fetch #{url}: #{inspect(reason)}")
    end
  end
end
