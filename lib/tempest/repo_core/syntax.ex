defmodule Tempest.RepoCore.Syntax do
  @moduledoc false

  @spec ascii?(binary()) :: boolean()
  def ascii?(value) when is_binary(value) do
    value
    |> :binary.bin_to_list()
    |> Enum.all?(&(&1 in 0x00..0x7F))
  end

  @spec visible_ascii?(binary()) :: boolean()
  def visible_ascii?(value) when is_binary(value) do
    value
    |> :binary.bin_to_list()
    |> Enum.all?(&(&1 in 0x21..0x7E))
  end
end
