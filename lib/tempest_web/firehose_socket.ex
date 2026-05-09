defmodule TempestWeb.FirehoseSocket do
  @moduledoc """
  WebSocket handler for `com.atproto.sync.subscribeRepos`.
  """

  @behaviour WebSock

  alias Tempest.Sequencer
  alias Tempest.Sync.EventStream

  @max_frame_size 5_000_000

  defstruct [:last_seq]

  def init(%{cursor: cursor}) do
    with :ok <- Sequencer.subscribe(),
         {:ok, start_seq} <- start_seq(cursor),
         {:ok, events} <- Sequencer.list_after(start_seq),
         {:ok, frames} <- encode_events(events) do
      state = %__MODULE__{last_seq: last_seq(events, start_seq)}

      if frames == [] do
        {:ok, state}
      else
        {:push, Enum.map(frames, &{:binary, &1}), state}
      end
    else
      {:error, :invalid_cursor} ->
        close_with_error("InvalidRequest", "cursor must be a non-negative integer")

      {:error, reason} ->
        close_with_error("InternalServerError", "failed to initialize stream: #{inspect(reason)}")
    end
  end

  def handle_in(_message, state), do: {:ok, state}

  def handle_info({:tempest_firehose_event, %Sequencer.Event{} = event}, %__MODULE__{} = state) do
    if event.seq > state.last_seq do
      with {:ok, frame} <- EventStream.encode_message(event),
           :ok <- ensure_frame_size(frame) do
        {:push, {:binary, frame}, %{state | last_seq: event.seq}}
      else
        {:error, reason} ->
          close_with_error("InternalServerError", "failed to encode event: #{inspect(reason)}", state)
      end
    else
      {:ok, state}
    end
  end

  def handle_info(_message, state), do: {:ok, state}

  defp start_seq(nil), do: Sequencer.current_seq()
  defp start_seq(cursor) when is_integer(cursor) and cursor >= 0, do: {:ok, cursor}
  defp start_seq(_cursor), do: {:error, :invalid_cursor}

  defp encode_events(events) do
    Enum.reduce_while(events, {:ok, []}, fn event, {:ok, frames} ->
      with {:ok, frame} <- EventStream.encode_message(event),
           :ok <- ensure_frame_size(frame) do
        {:cont, {:ok, [frame | frames]}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, frames} -> {:ok, Enum.reverse(frames)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensure_frame_size(frame) do
    if byte_size(frame) <= @max_frame_size do
      :ok
    else
      {:error, :frame_too_large}
    end
  end

  defp last_seq([], start_seq), do: start_seq
  defp last_seq(events, _start_seq), do: events |> List.last() |> Map.fetch!(:seq)

  defp close_with_error(error, message, state \\ %__MODULE__{last_seq: 0}) do
    case EventStream.encode_error(error, message) do
      {:ok, frame} -> {:stop, :normal, 1000, {:binary, frame}, state}
      {:error, reason} -> {:stop, {:error, reason}, state}
    end
  end
end
