defmodule Tempest.Admin.RepoOps do
  @moduledoc """
  Repository verification, export, and import helpers for operator tasks.
  """

  alias Tempest.Accounts.{Account, AuthContext}
  alias Tempest.{Records, Repo, RepoStorage}
  alias Tempest.RepoCore.CarVerifier

  def verify(did) when is_binary(did) do
    with {:ok, export} <- RepoStorage.export_car(did),
         {:ok, verified} <- CarVerifier.verify_repo_car(export.bytes, did: did) do
      {:ok,
       %{
         did: did,
         root: export.root,
         commit: verified.commit_cid,
         rev: verified.commit.rev,
         record_count: map_size(verified.entries),
         block_count: length(verified.car.blocks)
       }}
    end
  end

  def export(did, path) when is_binary(did) and is_binary(path) do
    with {:ok, export} <- RepoStorage.export_car(did),
         :ok <- File.mkdir_p(Path.dirname(path)),
         :ok <- File.write(path, export.bytes) do
      {:ok, %{did: did, root: export.root, path: path, bytes: byte_size(export.bytes)}}
    end
  end

  def import(did, path) when is_binary(did) and is_binary(path) do
    with %Account{} = account <- Repo.get_by(Account, did: did),
         {:ok, bytes} <- File.read(path),
         {:ok, result} <- Records.import_repo(%AuthContext{account: account, token_type: :admin}, bytes) do
      {:ok, result}
    else
      nil -> {:error, :account_not_found}
      {:error, reason} -> {:error, reason}
    end
  end
end
