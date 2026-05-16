defmodule Tempest.Blobs.StorageAdapterContractTest do
  use ExUnit.Case, async: true

  alias Tempest.Blobs.LocalStorage
  alias Tempest.Blobs.S3Storage
  alias Tempest.Blobs.StorageAdapter

  test "local and S3 adapters implement the storage contract callbacks" do
    for adapter <- [LocalStorage, S3Storage],
        {function, arity} <- StorageAdapter.behaviour_info(:callbacks) do
      Code.ensure_loaded!(adapter)

      assert function_exported?(adapter, function, arity),
             "#{inspect(adapter)} must export #{function}/#{arity}"
    end
  end
end
