defmodule Tempest.Identity.Validators do
  @moduledoc """
  Syntax validation for AT Protocol identity values.
  """

  @supported_did_methods ~w(plc web)

  def normalize_handle(handle) when is_binary(handle) do
    handle
    |> String.trim()
    |> String.downcase()
    |> String.trim_trailing(".")
  end

  def normalize_handle(handle), do: handle

  def validate_did(did) when is_binary(did) do
    did = String.trim(did)

    with [_, method, identifier] <- Regex.run(~r/\Adid:([a-z0-9]+):([A-Za-z0-9._:%-]+)\z/, did),
         :ok <- validate_did_method(method),
         :ok <- validate_did_identifier(method, identifier) do
      :ok
    else
      {:error, reason} -> {:error, reason}
      _other -> {:error, :invalid_did_syntax}
    end
  end

  def validate_did(_did), do: {:error, :invalid_did_syntax}

  def validate_handle(handle) when is_binary(handle) do
    handle = normalize_handle(handle)
    labels = String.split(handle, ".")

    cond do
      handle == "" ->
        {:error, :invalid_handle_syntax}

      byte_size(handle) > 253 ->
        {:error, :invalid_handle_syntax}

      length(labels) < 2 ->
        {:error, :invalid_handle_syntax}

      Enum.any?(labels, &(&1 == "")) ->
        {:error, :invalid_handle_syntax}

      not Enum.all?(labels, &valid_handle_label?/1) ->
        {:error, :invalid_handle_syntax}

      handle |> String.split(".") |> List.last() |> numeric?() ->
        {:error, :invalid_handle_syntax}

      true ->
        :ok
    end
  end

  def validate_handle(_handle), do: {:error, :invalid_handle_syntax}

  def supported_did_method?(method), do: method in @supported_did_methods

  defp validate_did_method(method) do
    if supported_did_method?(method) do
      :ok
    else
      {:error, :unsupported_did_method}
    end
  end

  defp validate_did_identifier("plc", identifier) do
    if String.match?(identifier, ~r/\A[a-z2-7]{24,}\z/) do
      :ok
    else
      {:error, :invalid_did_syntax}
    end
  end

  defp validate_did_identifier("web", identifier) do
    identifier
    |> String.replace(":", ".")
    |> validate_handle()
  end

  defp valid_handle_label?(label) do
    byte_size(label) <= 63 and
      String.match?(label, ~r/\A[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\z/)
  end

  defp numeric?(value), do: String.match?(value, ~r/\A[0-9]+\z/)
end
