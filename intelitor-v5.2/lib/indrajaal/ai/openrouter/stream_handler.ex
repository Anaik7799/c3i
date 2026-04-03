defmodule Indrajaal.AI.OpenRouter.StreamHandler do
  @moduledoc """
  SSE (Server-Sent Events) streaming decoder for OpenRouter API.

  Handles chunked streaming responses from OpenRouter, buffering partial
  events and parsing complete SSE data into structured events.

  ## STAMP Constraints

  - SC-AI-STREAM-001: Non-blocking SSE via GenStage (stateless parsing)
  - SC-AI-STREAM-002: Partial data buffering for incomplete events
  - SC-AI-STREAM-003: Backpressure support for slow consumers

  ## SSE Format

  OpenRouter streams responses as Server-Sent Events:

      data: {"id":"gen-123","choices":[{"delta":{"content":"Hello"}}]}

      data: {"id":"gen-123","choices":[{"delta":{"content":" world"}}]}

      data: [DONE]

  ## Usage

      state = StreamHandler.new_state()

      {:ok, events, state} = StreamHandler.decode_chunk(chunk1, state)
      {:ok, events, state} = StreamHandler.decode_chunk(chunk2, state)

      content = StreamHandler.collect_content(all_events)

  """

  require Logger

  @type event :: %{
          type: :data | :done,
          content: String.t() | nil,
          role: String.t() | nil,
          id: String.t() | nil,
          finish_reason: String.t() | nil
        }

  @type state :: %{
          buffer: String.t(),
          event_count: non_neg_integer(),
          started_at: DateTime.t()
        }

  @type result :: %{
          content: String.t(),
          finish_reason: String.t() | nil,
          id: String.t() | nil,
          role: String.t() | nil
        }

  @doc """
  Creates a new decoder state.

  Returns a state map with empty buffer and zero event count.
  """
  @spec new_state() :: state()
  def new_state do
    %{
      buffer: "",
      event_count: 0,
      started_at: DateTime.utc_now()
    }
  end

  @doc """
  Parses a single SSE event string into a structured event.

  ## Examples

      iex> StreamHandler.parse_sse_event("data: {\\"id\\":\\"123\\",\\"choices\\":[{\\"delta\\":{\\"content\\":\\"Hi\\"}}]}\\n\\n")
      {:ok, %{type: :data, content: "Hi", id: "123"}}

      iex> StreamHandler.parse_sse_event("data: [DONE]\\n\\n")
      {:ok, %{type: :done}}

  """
  @spec parse_sse_event(String.t()) :: {:ok, event()} | {:error, atom()}
  def parse_sse_event(raw) when is_binary(raw) do
    raw
    |> String.trim()
    |> extract_data_field()
    |> parse_data_content()
  end

  @doc """
  Decodes a chunk of SSE data, handling partial events via buffering.

  Returns parsed events and updated state. Incomplete events are buffered
  for the next chunk.

  ## Examples

      iex> state = StreamHandler.new_state()
      iex> {:ok, events, state} = StreamHandler.decode_chunk("data: {...}\\n\\n", state)

  """
  @spec decode_chunk(String.t(), state()) :: {:ok, [event()], state()}
  def decode_chunk(chunk, state) when is_binary(chunk) do
    combined = state.buffer <> chunk

    # Split on double newline (SSE event delimiter)
    parts = String.split(combined, "\n\n", trim: false)

    # Last part may be incomplete
    {complete_parts, incomplete} = split_complete_incomplete(parts)

    # Parse complete events
    {events, error_count} = parse_events(complete_parts)

    if error_count > 0 do
      Logger.debug("[StreamHandler] Skipped #{error_count} malformed events")
    end

    new_state = %{
      state
      | buffer: incomplete,
        event_count: state.event_count + length(events)
    }

    {:ok, events, new_state}
  end

  @doc """
  Collects content strings from a list of events.

  Concatenates all content fields from :data events, ignoring nil values.

  ## Examples

      iex> events = [%{type: :data, content: "Hello"}, %{type: :data, content: " world"}]
      iex> StreamHandler.collect_content(events)
      "Hello world"

  """
  @spec collect_content([event()]) :: String.t()
  def collect_content(events) when is_list(events) do
    events
    |> Enum.filter(&(&1[:type] == :data && &1[:content] != nil))
    |> Enum.map_join("", & &1[:content])
  end

  @doc """
  Converts a list of streaming events into an API result format.

  Extracts content, finish_reason, id, and role from the event stream.
  """
  @spec stream_to_result([event()]) :: result()
  def stream_to_result(events) when is_list(events) do
    content = collect_content(events)

    # Find finish_reason from events
    finish_reason =
      events
      |> Enum.find_value(fn event -> event[:finish_reason] end)

    # Find id from first event with id
    id =
      events
      |> Enum.find_value(fn event -> event[:id] end)

    # Find role from first event with role
    role =
      events
      |> Enum.find_value(fn event -> event[:role] end)

    %{
      content: content,
      finish_reason: finish_reason,
      id: id,
      role: role
    }
  end

  # Private functions

  defp extract_data_field(raw) do
    # Handle multi-line SSE format
    lines = String.split(raw, "\n", trim: true)

    data_line =
      Enum.find(lines, fn line ->
        String.starts_with?(line, "data:")
      end)

    case data_line do
      nil ->
        {:error, :no_data_field}

      line ->
        data_content = String.trim_leading(line, "data:")
        {:ok, String.trim(data_content)}
    end
  end

  defp parse_data_content({:error, reason}), do: {:error, reason}

  defp parse_data_content({:ok, ""}) do
    {:error, :empty_data}
  end

  defp parse_data_content({:ok, "[DONE]"}) do
    {:ok, %{type: :done}}
  end

  defp parse_data_content({:ok, json_str}) do
    case Jason.decode(json_str) do
      {:ok, data} ->
        parse_openrouter_payload(data)

      {:error, _} ->
        {:error, :invalid_json}
    end
  end

  defp parse_openrouter_payload(data) when is_map(data) do
    choices = Map.get(data, "choices", [])
    first_choice = List.first(choices) || %{}
    delta = Map.get(first_choice, "delta", %{})

    event = %{
      type: :data,
      content: Map.get(delta, "content"),
      role: Map.get(delta, "role"),
      id: Map.get(data, "id"),
      finish_reason: Map.get(first_choice, "finish_reason")
    }

    {:ok, event}
  end

  defp parse_openrouter_payload(_) do
    {:error, :invalid_payload}
  end

  defp split_complete_incomplete(parts) do
    case parts do
      [] ->
        {[], ""}

      [single] ->
        # Single part without delimiter - incomplete
        {[], single}

      multiple ->
        # Last element is either empty (complete stream) or incomplete
        {complete, [last]} = Enum.split(multiple, -1)
        {complete, last}
    end
  end

  defp parse_events(parts) do
    parts
    |> Enum.filter(&(String.trim(&1) != ""))
    |> Enum.map(fn part ->
      # Re-add the data: prefix if needed for parsing
      normalized =
        if String.starts_with?(String.trim(part), "data:") do
          part
        else
          "data: " <> part
        end

      parse_sse_event(normalized <> "\n\n")
    end)
    |> Enum.reduce({[], 0}, fn result, {events, errors} ->
      case result do
        {:ok, event} -> {events ++ [event], errors}
        {:error, _} -> {events, errors + 1}
      end
    end)
  end
end
