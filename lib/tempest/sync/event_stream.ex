defmodule Tempest.Sync.EventStream do
  @moduledoc """
  Binary atproto event-stream frame encoding.
  """

  alias Tempest.RepoCore.{Cid, Drisl}
  alias Tempest.Sequencer.Event

  @max_frame_bytes 5_000_000

  def encode_message(%Event{} = event) do
    with {:ok, header} <- Drisl.encode(%{"op" => 1, "t" => event.event_type}),
         {:ok, payload} <- event |> payload() |> Drisl.encode(),
         frame = header <> payload,
         :ok <- check_frame_size(frame) do
      {:ok, frame}
    end
  end

  def encode_error(error, message) when is_binary(error) and is_binary(message) do
    with {:ok, header} <- Drisl.encode(%{"op" => -1}),
         {:ok, payload} <- Drisl.encode(%{"error" => error, "message" => message}) do
      {:ok, header <> payload}
    end
  end

  defp payload(%Event{event_type: "#commit", payload: payload}) do
    payload
    |> Map.delete("$type")
    |> Map.delete("did")
    |> Map.put("repo", Map.fetch!(payload, "did"))
    |> normalize_commit_links()
  end

  defp payload(%Event{payload: payload}) do
    Map.delete(payload, "$type")
  end

  defp normalize_commit_links(payload) do
    payload
    |> update_cid_link("commit")
    |> update_ops()
  end

  defp update_cid_link(payload, key) do
    case Map.fetch(payload, key) do
      {:ok, value} when is_binary(value) ->
        case Cid.parse(value) do
          {:ok, cid} -> Map.put(payload, key, cid)
          {:error, _reason} -> payload
        end

      _other ->
        payload
    end
  end

  defp update_ops(%{"ops" => ops} = payload) when is_list(ops) do
    Map.put(payload, "ops", Enum.map(ops, &update_cid_link(&1, "cid")))
  end

  defp update_ops(payload), do: payload

  defp check_frame_size(frame) do
    if byte_size(frame) <= @max_frame_bytes do
      :ok
    else
      {:error, :frame_too_large}
    end
  end
end
