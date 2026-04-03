defmodule Indrajaal.Metabolic.EventSourcingIntegrationTest do
  @moduledoc """
  L4.3: Event Sourcing Pipeline Integration Tests.

  Tests the event sourcing infrastructure:
  - Event store operations (append, read, subscribe)
  - Stream management
  - HLC timestamp ordering
  - Causal dependency tracking
  - Event immutability

  STAMP Constraints:
  - SC-EVT-001: Events MUST be immutable
  - SC-EVT-002: Event order MUST be preserved within stream
  - SC-EVT-003: HLC timestamps MUST be monotonic
  - SC-EVT-004: Causal dependencies MUST be tracked
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Cybernetic.EventSourcing.EventStore

  setup do
    # Start a fresh EventStore for each test
    name = :"event_store_#{System.unique_integer()}"
    {:ok, pid} = EventStore.start_link(name: name)

    on_exit(fn ->
      if Process.alive?(pid) do
        GenServer.stop(pid, :normal, 100)
      end
    end)

    {:ok, store: name, pid: pid}
  end

  describe "L4.3: EventStore Module" do
    test "EventStore module is defined" do
      assert Code.ensure_loaded?(EventStore)
    end

    test "EventStore exports append/4" do
      assert function_exported?(EventStore, :append, 4)
    end

    test "EventStore exports read/2" do
      assert function_exported?(EventStore, :read, 2)
    end

    test "EventStore exports subscribe/2" do
      assert function_exported?(EventStore, :subscribe, 2)
    end

    test "EventStore exports stream_version/1" do
      assert function_exported?(EventStore, :stream_version, 1)
    end

    test "EventStore exports list_streams/0" do
      assert function_exported?(EventStore, :list_streams, 0)
    end
  end

  describe "L4.3: Event Append Operations (SC-EVT-001)" do
    test "append returns {:ok, event} with valid data", %{pid: pid} do
      result = GenServer.call(pid, {:append, "test_stream", :test_event, %{value: 42}, []})

      assert {:ok, event} = result
      assert event.stream == "test_stream"
      assert event.type == :test_event
      assert event.data == %{value: 42}
      assert event.version == 1
    end

    test "appended event has unique ID", %{pid: pid} do
      {:ok, event1} = GenServer.call(pid, {:append, "stream1", :evt, %{}, []})
      {:ok, event2} = GenServer.call(pid, {:append, "stream1", :evt, %{}, []})

      assert event1.id != event2.id
    end

    test "appended event has HLC timestamp", %{pid: pid} do
      {:ok, event} = GenServer.call(pid, {:append, "stream", :evt, %{}, []})

      assert is_integer(event.hlc_timestamp)
      assert event.hlc_timestamp > 0
    end

    test "appended event has causal_deps", %{pid: pid} do
      {:ok, event} = GenServer.call(pid, {:append, "stream", :evt, %{}, []})

      assert is_map(event.causal_deps)
    end

    test "appended event has metadata", %{pid: pid} do
      {:ok, event} = GenServer.call(pid, {:append, "stream", :evt, %{}, []})

      assert is_map(event.metadata)
      assert Map.has_key?(event.metadata, :timestamp)
      assert Map.has_key?(event.metadata, :correlation_id)
    end
  end

  describe "L4.3: Event Order Preservation (SC-EVT-002)" do
    test "events maintain version order within stream", %{pid: pid} do
      for i <- 1..5 do
        GenServer.call(pid, {:append, "ordered_stream", :evt, %{seq: i}, []})
      end

      {:ok, events} = GenServer.call(pid, {:read, "ordered_stream", []})

      versions = Enum.map(events, & &1.version)
      assert versions == [1, 2, 3, 4, 5]
    end

    test "events maintain insertion order", %{pid: pid} do
      for i <- 1..3 do
        GenServer.call(pid, {:append, "ordered", :evt, %{seq: i}, []})
      end

      {:ok, events} = GenServer.call(pid, {:read, "ordered", []})
      sequences = Enum.map(events, fn e -> e.data.seq end)

      assert sequences == [1, 2, 3]
    end

    test "different streams have independent versions", %{pid: pid} do
      GenServer.call(pid, {:append, "stream_a", :evt, %{}, []})
      GenServer.call(pid, {:append, "stream_a", :evt, %{}, []})
      GenServer.call(pid, {:append, "stream_b", :evt, %{}, []})

      {:ok, events_a} = GenServer.call(pid, {:read, "stream_a", []})
      {:ok, events_b} = GenServer.call(pid, {:read, "stream_b", []})

      assert length(events_a) == 2
      assert length(events_b) == 1
      assert hd(events_b).version == 1
    end
  end

  describe "L4.3: HLC Monotonicity (SC-EVT-003)" do
    test "HLC timestamps are monotonically increasing", %{pid: pid} do
      {:ok, event1} = GenServer.call(pid, {:append, "hlc_stream", :evt, %{}, []})
      {:ok, event2} = GenServer.call(pid, {:append, "hlc_stream", :evt, %{}, []})
      {:ok, event3} = GenServer.call(pid, {:append, "hlc_stream", :evt, %{}, []})

      assert event1.hlc_timestamp < event2.hlc_timestamp
      assert event2.hlc_timestamp < event3.hlc_timestamp
    end

    test "HLC timestamps are greater than zero", %{pid: pid} do
      {:ok, event} = GenServer.call(pid, {:append, "stream", :evt, %{}, []})

      assert event.hlc_timestamp > 0
    end
  end

  describe "L4.3: Causal Dependencies (SC-EVT-004)" do
    test "vector clock increments with each event", %{pid: pid} do
      {:ok, event1} = GenServer.call(pid, {:append, "vc_stream", :evt, %{}, []})
      {:ok, event2} = GenServer.call(pid, {:append, "vc_stream", :evt, %{}, []})

      # Vector clock should have at least one entry
      assert map_size(event1.causal_deps) >= 1
      assert map_size(event2.causal_deps) >= 1

      # Get the node's entry in vector clock
      [node_key | _] = Map.keys(event1.causal_deps)
      vc1_value = event1.causal_deps[node_key]
      vc2_value = event2.causal_deps[node_key]

      assert vc2_value > vc1_value
    end
  end

  describe "L4.3: Stream Reading" do
    test "read returns empty list for nonexistent stream", %{pid: pid} do
      result = GenServer.call(pid, {:read, "nonexistent_stream", []})

      assert {:ok, []} = result
    end

    test "read returns all events from stream", %{pid: pid} do
      GenServer.call(pid, {:append, "read_stream", :evt1, %{a: 1}, []})
      GenServer.call(pid, {:append, "read_stream", :evt2, %{b: 2}, []})

      {:ok, events} = GenServer.call(pid, {:read, "read_stream", []})

      assert length(events) == 2
    end

    test "read with from_version filter works", %{pid: pid} do
      for i <- 1..5 do
        GenServer.call(pid, {:append, "filter_stream", :evt, %{n: i}, []})
      end

      {:ok, events} = GenServer.call(pid, {:read, "filter_stream", [from_version: 3]})

      versions = Enum.map(events, & &1.version)
      assert versions == [4, 5]
    end

    test "read with to_version filter works", %{pid: pid} do
      for i <- 1..5 do
        GenServer.call(pid, {:append, "filter_stream2", :evt, %{n: i}, []})
      end

      {:ok, events} = GenServer.call(pid, {:read, "filter_stream2", [to_version: 3]})

      versions = Enum.map(events, & &1.version)
      assert versions == [1, 2, 3]
    end

    test "read with type filter works", %{pid: pid} do
      GenServer.call(pid, {:append, "type_stream", :type_a, %{}, []})
      GenServer.call(pid, {:append, "type_stream", :type_b, %{}, []})
      GenServer.call(pid, {:append, "type_stream", :type_a, %{}, []})

      {:ok, events} = GenServer.call(pid, {:read, "type_stream", [type: :type_a]})

      assert length(events) == 2
      assert Enum.all?(events, fn e -> e.type == :type_a end)
    end

    test "read with limit filter works", %{pid: pid} do
      for i <- 1..10 do
        GenServer.call(pid, {:append, "limit_stream", :evt, %{n: i}, []})
      end

      {:ok, events} = GenServer.call(pid, {:read, "limit_stream", [limit: 3]})

      assert length(events) == 3
    end
  end

  describe "L4.3: Stream Version" do
    test "stream_version returns 0 for nonexistent stream", %{pid: pid} do
      version = GenServer.call(pid, {:version, "nonexistent"})
      assert version == 0
    end

    test "stream_version increments with appends", %{pid: pid} do
      GenServer.call(pid, {:append, "version_stream", :evt, %{}, []})
      assert GenServer.call(pid, {:version, "version_stream"}) == 1

      GenServer.call(pid, {:append, "version_stream", :evt, %{}, []})
      assert GenServer.call(pid, {:version, "version_stream"}) == 2
    end
  end

  describe "L4.3: Stream Listing" do
    test "list_streams returns empty list initially", %{pid: pid} do
      streams = GenServer.call(pid, :list_streams)
      assert streams == []
    end

    test "list_streams returns all stream names", %{pid: pid} do
      GenServer.call(pid, {:append, "stream_1", :evt, %{}, []})
      GenServer.call(pid, {:append, "stream_2", :evt, %{}, []})
      GenServer.call(pid, {:append, "stream_3", :evt, %{}, []})

      streams = GenServer.call(pid, :list_streams)

      assert length(streams) == 3
      assert "stream_1" in streams
      assert "stream_2" in streams
      assert "stream_3" in streams
    end
  end

  describe "L4.3: Subscription" do
    test "subscribe/2 allows subscription to stream events", %{pid: pid} do
      GenServer.cast(pid, {:subscribe, "sub_stream", self()})

      # Give time for cast to process
      Process.sleep(10)

      # Append an event
      GenServer.call(pid, {:append, "sub_stream", :test_event, %{data: "hello"}, []})

      # Should receive event notification
      assert_receive {:event, "sub_stream", event}, 1000
      assert event.type == :test_event
      assert event.data == %{data: "hello"}
    end
  end

  describe "L4.3: Event Metadata" do
    test "events include correlation_id in metadata", %{pid: pid} do
      {:ok, event} = GenServer.call(pid, {:append, "meta_stream", :evt, %{}, []})

      assert event.metadata.correlation_id != nil
    end

    test "events can have custom actor in metadata", %{pid: pid} do
      {:ok, event} =
        GenServer.call(
          pid,
          {:append, "actor_stream", :evt, %{}, [actor: "user:123"]}
        )

      assert event.metadata.actor == "user:123"
    end

    test "events can have custom correlation_id", %{pid: pid} do
      {:ok, event} =
        GenServer.call(
          pid,
          {:append, "corr_stream", :evt, %{}, [correlation_id: "req-abc"]}
        )

      assert event.metadata.correlation_id == "req-abc"
    end

    test "events can have causation_id", %{pid: pid} do
      {:ok, event} =
        GenServer.call(
          pid,
          {:append, "cause_stream", :evt, %{}, [causation_id: "event-xyz"]}
        )

      assert event.metadata.causation_id == "event-xyz"
    end
  end

  describe "L4.3: Event Store State" do
    test "event store starts successfully", %{pid: pid} do
      assert Process.alive?(pid)
    end

    test "event store maintains state across operations", %{pid: pid} do
      GenServer.call(pid, {:append, "persist_stream", :evt1, %{a: 1}, []})
      GenServer.call(pid, {:append, "persist_stream", :evt2, %{b: 2}, []})

      {:ok, events} = GenServer.call(pid, {:read, "persist_stream", []})
      assert length(events) == 2
    end
  end
end
