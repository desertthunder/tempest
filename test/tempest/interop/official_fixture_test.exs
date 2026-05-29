defmodule Tempest.Interop.OfficialFixtureTest do
  use ExUnit.Case, async: true

  alias Tempest.Lexicon.{Bundled, Document}
  alias Tempest.RepoCore.{Car, FixtureImporter}

  test "bundled interop Lexicon fixture set is internally valid and sourced" do
    assert :ok = Document.validate_documents(Bundled.documents())
    assert Bundled.manifest()["source_commit"] =~ ~r/^[0-9a-f]{40}$/
  end

  test "invalid repo import fixtures fail safely for Milestone 12 handoff" do
    assert Car.decode(<<0, 1, 2, 3>>) == {:error, :zero_length_header}
    assert FixtureImporter.import_car(<<0, 1, 2, 3>>, did_document: %{}) == {:error, {:car_error, :zero_length_header}}
  end
end
