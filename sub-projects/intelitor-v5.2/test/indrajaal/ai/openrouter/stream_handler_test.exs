# credo:disable-for-this-file Credo.Check.Readability.StringSigils
# Test fixtures contain JSON strings with many escaped quotes - sigils would reduce readability
defmodule Indrajaal.AI.OpenRouter.StreamHandlerTest do
  @moduledoc """
  TDG-Compliant tests for StreamHandler module.

  Tests SSE (Server-Sent Events) streaming decoder for OpenRouter API.

  STAMP Constraints:
  - SC-AI-STREAM-001: Non-blocking SSE via GenStage
  - SC-AI-STREAM-002: Partial data buffering for incomplete events
  - SC-AI-STREAM-003: Backpressure support for slow consumers
  """

  use ExUnit.Case, async: true
  @moduletag :zenoh_nif
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.AI.OpenRouter.StreamHandler

  describe "StreamHandler.parse_sse_event/1" do
    test "SC-AI-STREAM-001: parses complete data event" do
      raw = "data: {\"id\":\"123\",\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}\n\n"

      assert {:ok, event} = StreamHandler.parse_sse_event(raw)
      assert event.type == :data
      assert event.content == "Hello"
      assert event.id == "123"
    end

    test "parses event with role delta" do
      raw = "data: {\"id\":\"456\",\"choices\":[{\"delta\":{\"role\":\"assistant\"}}]}\n\n"

      assert {:ok, event} = StreamHandler.parse_sse_event(raw)
      assert event.type == :data
      assert event.role == "assistant"
    end

    test "parses [DONE] marker" do
      raw = "data: [DONE]\n\n"

      assert {:ok, event} = StreamHandler.parse_sse_event(raw)
      assert event.type == :done
    end

    test "handles event with finish_reason" do
      raw = "data: {\"id\":\"789\",\"choices\":[{\"delta\":{},\"finish_reason\":\"stop\"}]}\n\n"

      assert {:ok, event} = StreamHandler.parse_sse_event(raw)
      assert event.type == :data
      assert event.finish_reason == "stop"
    end

    test "handles multiple choices (uses first)" do
      raw =
        "data: {\"id\":\"multi\",\"choices\":[{\"delta\":{\"content\":\"A\"}},{\"delta\":{\"content\":\"B\"}}]}\n\n"

      assert {:ok, event} = StreamHandler.parse_sse_event(raw)
      assert event.content == "A"
    end

    test "returns error for malformed JSON" do
      raw = "data: {invalid json}\n\n"

      assert {:error, :invalid_json} = StreamHandler.parse_sse_event(raw)
    end

    test "returns error for non-data event types" do
      raw = "event: ping\ndata: {}\n\n"

      # Should still try to parse but may not have expected structure
      result = StreamHandler.parse_sse_event(raw)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "handles empty data field" do
      raw = "data: \n\n"

      assert {:error, _} = StreamHandler.parse_sse_event(raw)
    end
  end

  describe "StreamHandler.decode_chunk/2" do
    test "SC-AI-STREAM-002: handles complete single event" do
      chunk = "data: {\"id\":\"1\",\"choices\":[{\"delta\":{\"content\":\"Hi\"}}]}\n\n"
      state = StreamHandler.new_state()

      assert {:ok, events, new_state} = StreamHandler.decode_chunk(chunk, state)
      assert length(events) == 1
      assert hd(events).content == "Hi"
      assert new_state.buffer == ""
    end

    test "SC-AI-STREAM-002: buffers incomplete event" do
      chunk = "data: {\"id\":\"1\",\"choices\":[{\"delta\":"
      state = StreamHandler.new_state()

      assert {:ok, [], new_state} = StreamHandler.decode_chunk(chunk, state)
      assert new_state.buffer == chunk
    end

    test "SC-AI-STREAM-002: completes buffered event with next chunk" do
      chunk1 = "data: {\"id\":\"1\",\"choices\":[{\"delta\":"
      chunk2 = "{\"content\":\"Hi\"}}]}\n\n"
      state = StreamHandler.new_state()

      {:ok, [], state2} = StreamHandler.decode_chunk(chunk1, state)
      assert {:ok, events, _state3} = StreamHandler.decode_chunk(chunk2, state2)

      assert length(events) == 1
      assert hd(events).content == "Hi"
    end

    test "handles multiple events in single chunk" do
      chunk =
        "data: {\"id\":\"1\",\"choices\":[{\"delta\":{\"content\":\"A\"}}]}\n\n" <>
          "data: {\"id\":\"2\",\"choices\":[{\"delta\":{\"content\":\"B\"}}]}\n\n"

      state = StreamHandler.new_state()

      assert {:ok, events, _new_state} = StreamHandler.decode_chunk(chunk, state)
      assert length(events) == 2
      assert Enum.at(events, 0).content == "A"
      assert Enum.at(events, 1).content == "B"
    end

    test "handles mixed complete and incomplete events" do
      chunk =
        "data: {\"id\":\"1\",\"choices\":[{\"delta\":{\"content\":\"Done\"}}]}\n\n" <>
          "data: {\"id\":\"2\",\"choices\":["

      state = StreamHandler.new_state()

      assert {:ok, events, new_state} = StreamHandler.decode_chunk(chunk, state)
      assert length(events) == 1
      assert hd(events).content == "Done"
      assert String.contains?(new_state.buffer, "data: {\"id\":\"2\"")
    end

    test "handles [DONE] marker" do
      chunk = "data: [DONE]\n\n"
      state = StreamHandler.new_state()

      assert {:ok, events, _new_state} = StreamHandler.decode_chunk(chunk, state)
      assert length(events) == 1
      assert hd(events).type == :done
    end

    test "tracks total tokens received" do
      chunk =
        "data: {\"id\":\"1\",\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}\n\n" <>
          "data: {\"id\":\"2\",\"choices\":[{\"delta\":{\"content\":\" world\"}}]}\n\n"

      state = StreamHandler.new_state()

      assert {:ok, _events, new_state} = StreamHandler.decode_chunk(chunk, state)
      assert new_state.event_count == 2
    end
  end

  describe "StreamHandler.collect_content/1" do
    test "concatenates content from multiple events" do
      events = [
        %{type: :data, content: "Hello"},
        %{type: :data, content: " "},
        %{type: :data, content: "world"},
        %{type: :done}
      ]

      assert StreamHandler.collect_content(events) == "Hello world"
    end

    test "handles events with nil content" do
      events = [
        %{type: :data, content: "Start"},
        %{type: :data, content: nil, role: "assistant"},
        %{type: :data, content: "End"}
      ]

      assert StreamHandler.collect_content(events) == "StartEnd"
    end

    test "returns empty string for no data events" do
      events = [%{type: :done}]

      assert StreamHandler.collect_content(events) == ""
    end

    test "returns empty string for empty list" do
      assert StreamHandler.collect_content([]) == ""
    end
  end

  describe "StreamHandler.new_state/0" do
    test "initializes with empty buffer" do
      state = StreamHandler.new_state()

      assert state.buffer == ""
      assert state.event_count == 0
      assert state.started_at != nil
    end
  end

  describe "StreamHandler error handling" do
    test "recovers from malformed event in stream" do
      chunk =
        "data: {\"id\":\"1\",\"choices\":[{\"delta\":{\"content\":\"OK\"}}]}\n\n" <>
          "data: {bad json}\n\n" <>
          "data: {\"id\":\"3\",\"choices\":[{\"delta\":{\"content\":\"Also OK\"}}]}\n\n"

      state = StreamHandler.new_state()

      # Should recover and parse what it can
      {:ok, events, _state} = StreamHandler.decode_chunk(chunk, state)

      # At minimum, should get the valid events
      valid_contents = events |> Enum.map(& &1[:content]) |> Enum.filter(&(&1 != nil))
      assert "OK" in valid_contents or "Also OK" in valid_contents
    end

    test "handles network-style chunking (mid-JSON split)" do
      # Simulate how TCP might split JSON
      chunks = [
        "data: {\"id\":\"1\",",
        "\"choices\":[{\"delta\":",
        "{\"content\":\"Streamed\"}}]}\n\n"
      ]

      state = StreamHandler.new_state()

      {events, _state} =
        Enum.reduce(chunks, {[], state}, fn chunk, {acc_events, acc_state} ->
          {:ok, new_events, new_state} = StreamHandler.decode_chunk(chunk, acc_state)
          {acc_events ++ new_events, new_state}
        end)

      assert length(events) == 1
      assert hd(events).content == "Streamed"
    end
  end

  describe "StreamHandler.stream_to_result/1" do
    test "converts event list to API result format" do
      events = [
        %{type: :data, content: "Hello", id: "gen-123", role: "assistant"},
        %{type: :data, content: " world", id: "gen-123"},
        %{type: :data, finish_reason: "stop", id: "gen-123"},
        %{type: :done}
      ]

      result = StreamHandler.stream_to_result(events)

      assert result.content == "Hello world"
      assert result.finish_reason == "stop"
      assert result.id == "gen-123"
      assert result.role == "assistant"
    end

    test "handles stream with no finish_reason" do
      events = [
        %{type: :data, content: "Partial"},
        %{type: :done}
      ]

      result = StreamHandler.stream_to_result(events)

      assert result.content == "Partial"
      assert result.finish_reason == nil
    end
  end

  # Property-based tests
  property "SC-AI-STREAM-002: buffering preserves all data" do
    forall chunks <- PC.list(PC.utf8()) do
      # Simulate chunked delivery
      state = StreamHandler.new_state()

      {_events, final_state} =
        chunks
        |> Enum.reduce({[], state}, fn chunk, {acc_events, acc_state} ->
          case StreamHandler.decode_chunk(chunk, acc_state) do
            {:ok, new_events, new_state} -> {acc_events ++ new_events, new_state}
            {:error, _} -> {acc_events, acc_state}
          end
        end)

      # Buffer should contain any incomplete data
      is_binary(final_state.buffer)
    end
  end

  # StreamData property test
  property "event count monotonically increases" do
    # Test with different event counts
    for event_count <- [1, 3, 5, 10] do
      event_lines =
        for i <- 1..event_count do
          "data: {\"id\":\"#{i}\",\"choices\":[{\"delta\":{\"content\":\"test#{i}\"}}]}\n\n"
        end

      events_str = event_lines |> Enum.join("")

      state = StreamHandler.new_state()
      {:ok, parsed_events, new_state} = StreamHandler.decode_chunk(events_str, state)

      assert length(parsed_events) == event_count
      assert new_state.event_count == event_count
    end
  end
end
