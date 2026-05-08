defmodule Tempest.RepoCore.RecordKeyTest do
  use ExUnit.Case, async: true

  alias Tempest.RepoCore.RecordKey

  describe "parse/1" do
    test "accepts official valid examples" do
      for record_key <- ["3jui7kd54zh2y", "self", "example.com", "~1.2-3_", "dHJ1ZQ", "pre:fix", "_"] do
        assert RecordKey.parse(record_key) == {:ok, record_key}
      end
    end

    test "rejects official invalid examples" do
      for record_key <- [
            "alpha/beta",
            ".",
            "..",
            "#extra",
            "@handle",
            "any space",
            "any+space",
            "number[3]",
            "number(3)",
            ~s("quote"),
            "dHJ1ZQ=="
          ] do
        assert RecordKey.parse(record_key) == {:error, :invalid_record_key_syntax}
      end
    end

    test "rejects empty, non-ascii, and oversized record keys" do
      assert RecordKey.parse("") == {:error, :invalid_record_key_syntax}
      assert RecordKey.parse("café") == {:error, :not_ascii}
      assert RecordKey.parse(String.duplicate("a", 513)) == {:error, :too_long}
    end
  end
end
