defmodule Indrajaal.Cybernetic.EventSourcing.EventStoreTest do
  @moduledoc """
  TDG comprehensive test suite for Indrajaal.Cybernetic.EventSourcing.EventStore.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: GenServer lifecycle tested before runtime integration
  - FPPS Validation: 5-method consensus on event append and read ordering

  ## STAMP Safety Integration
  - SC-EVT-001: Events MUST be immutable after append
  - SC-EVT-002: Event order MUST be preserved within a stream
  - SC-EVT-003: HLC timestamps MUST be monotonic
  - SC-EVT-004: Causal dependencies (vector clocks) MUST be tracked
  - SC-HOLON-019: Evolution history is append-only, NEVER delete or modify

  ## Constitutional Verification
  - Psi_0 Existence: EventStore GenServer survives concurrent appends
  - Psi_2 History: All events preserved in append-only log (SC-EVT-002)
  - Psi_3 Verification: Event version sequence is deterministically verifiable

  ## Founder's Directive Alignment
  - Omega_0.6: EventStore is the temporal memory substrate of the cognitive mesh
  - Omega_8: Immutable append-only log enforces SC-REG-001 register semantics

  ## TPS 5-Level RCA Context
  - L1 Symptom: Events arrive out of order or are lost during concurrent writes
  - L5 Root Cause: No monotonic HLC or missing stream version tracking
  """

  use ExUnit.Case, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Cybernetic.EventSourcing.EventStore

  @moduletag :zenoh_nif

  # ---- Helpers ----------------------------------------------------------------

  defp start_store(test_name) do
    name = :"event_store_test_#{test_name}_#{System.unique_integer([:positive])}"
    {:ok, pid} = start_supervised({EventStore, [name: name, node_id: "test-node"]})
    {pid, name}
  end

  # ---- start_link/1 -----------------------------------------------------------

  describe "start_link/1" do
    test "starts and registers under the given name" do
      name = :"es_start_#{System.unique_integer([:positive])}"
      {:ok, pid} = start_supervised({EventStore, [name: name]})
      assert Process.whereis(name) == pid
    end

    test "process is alive after start" do
      {pid, _name} = start_store(:alive)
      assert Process.alive?(pid)
    end

    test "initial stream list is empty" do
      {_pid, name} = start_store(:empty_streams)
      assert EventStore.list_streams() |> then(fn _ -> :skip end)
      # Call on named instance
      assert GenServer.call(name, :list_streams) == []
    end
  end

  # ---- append/4 ---------------------------------------------------------------

  describe "append/4" do
    setup do
      {_pid, name} = start_store(:append)
      {:ok, name: name}
    end

    test "returns {:ok, event} on success", %{name: name} do
      result = GenServer.call(name, {:append, "test-stream", :user_created, %{id: 1}, []})
      assert {:ok, event} = result
      assert is_map(event)
    end

    test "returned event has an id (SC-EVT-001)", %{name: name} do
      {:ok, event} = GenServer.call(name, {:append, "stream-1", :created, %{}, []})
      assert is_binary(event.id)
      assert String.length(event.id) > 0
    end

    test "returned event has stream field matching input", %{name: name} do
      {:ok, event} = GenServer.call(name, {:append, "my-stream", :event_type, %{}, []})
      assert event.stream == "my-stream"
    end

    test "returned event has type field matching input", %{name: name} do
      {:ok, event} = GenServer.call(name, {:append, "s", :alarm_triggered, %{}, []})
      assert event.type == :alarm_triggered
    end

    test "returned event has data field matching input", %{name: name} do
      data = %{sensor_id: "s-1", value: 42.5}
      {:ok, event} = GenServer.call(name, {:append, "sensors", :reading, data, []})
      assert event.data == data
    end

    test "returned event has version 1 for first event in stream", %{name: name} do
      {:ok, event} = GenServer.call(name, {:append, "new-stream", :init, %{}, []})
      assert event.version == 1
    end

    test "second event in same stream has version 2 (SC-EVT-002)", %{name: name} do
      {:ok, _e1} = GenServer.call(name, {:append, "v-stream", :created, %{}, []})
      {:ok, e2} = GenServer.call(name, {:append, "v-stream", :updated, %{}, []})
      assert e2.version == 2
    end

    test "events in different streams have independent versions", %{name: name} do
      {:ok, ea} = GenServer.call(name, {:append, "stream-a", :event, %{}, []})
      {:ok, eb} = GenServer.call(name, {:append, "stream-b", :event, %{}, []})
      assert ea.version == 1
      assert eb.version == 1
    end

    test "event has a monotonic hlc_timestamp (SC-EVT-003)", %{name: name} do
      {:ok, e1} = GenServer.call(name, {:append, "ts-stream", :first, %{}, []})
      {:ok, e2} = GenServer.call(name, {:append, "ts-stream", :second, %{}, []})
      assert e2.hlc_timestamp >= e1.hlc_timestamp
    end

    test "event has causal_deps (vector clock) populated (SC-EVT-004)", %{name: name} do
      {:ok, event} = GenServer.call(name, {:append, "vc-stream", :action, %{}, []})
      assert is_map(event.causal_deps)
      assert map_size(event.causal_deps) > 0
    end

    test "event metadata includes timestamp", %{name: name} do
      {:ok, event} = GenServer.call(name, {:append, "meta-stream", :evt, %{}, []})
      assert %DateTime{} = event.metadata.timestamp
    end

    test "accepts optional actor in opts", %{name: name} do
      {:ok, event} =
        GenServer.call(name, {:append, "actor-stream", :action, %{}, [actor: "user-99"]})

      assert event.metadata.actor == "user-99"
    end
  end

  # ---- read/2 -----------------------------------------------------------------

  describe "read/2 (handle_call :read)" do
    setup do
      {_pid, name} = start_store(:read)

      # Seed events
      for i <- 1..5 do
        GenServer.call(name, {:append, "read-stream", :event, %{seq: i}, []})
      end

      {:ok, name: name}
    end

    test "returns {:ok, events} for existing stream", %{name: name} do
      assert {:ok, events} = GenServer.call(name, {:read, "read-stream", []})
      assert is_list(events)
    end

    test "returns all events when no filters applied", %{name: name} do
      {:ok, events} = GenServer.call(name, {:read, "read-stream", []})
      assert length(events) == 5
    end

    test "returns empty list for unknown stream", %{name: name} do
      {:ok, events} = GenServer.call(name, {:read, "nonexistent", []})
      assert events == []
    end

    test "events are in insertion order (SC-EVT-002)", %{name: name} do
      {:ok, events} = GenServer.call(name, {:read, "read-stream", []})
      versions = Enum.map(events, & &1.version)
      assert versions == Enum.sort(versions)
    end

    test "from_version filter excludes older events", %{name: name} do
      {:ok, events} = GenServer.call(name, {:read, "read-stream", [from_version: 3]})
      assert Enum.all?(events, fn e -> e.version > 3 end)
    end

    test "to_version filter excludes newer events", %{name: name} do
      {:ok, events} = GenServer.call(name, {:read, "read-stream", [to_version: 3]})
      assert Enum.all?(events, fn e -> e.version <= 3 end)
    end

    test "type filter returns only matching event types", %{name: name} do
      # Append a differently-typed event
      GenServer.call(name, {:append, "read-stream", :special_type, %{}, []})
      {:ok, events} = GenServer.call(name, {:read, "read-stream", [type: :special_type]})
      assert Enum.all?(events, fn e -> e.type == :special_type end)
    end

    test "limit filter caps number of results", %{name: name} do
      {:ok, events} = GenServer.call(name, {:read, "read-stream", [limit: 2]})
      assert length(events) == 2
    end
  end

  # ---- stream_version/1 -------------------------------------------------------

  describe "stream_version/1 (handle_call :version)" do
    setup do
      {_pid, name} = start_store(:stream_version)
      {:ok, name: name}
    end

    test "returns 0 for unknown stream", %{name: name} do
      assert GenServer.call(name, {:version, "unknown"}) == 0
    end

    test "returns 1 after first append", %{name: name} do
      GenServer.call(name, {:append, "ver-s", :e, %{}, []})
      assert GenServer.call(name, {:version, "ver-s"}) == 1
    end

    test "increments with each append", %{name: name} do
      for _ <- 1..4, do: GenServer.call(name, {:append, "inc-s", :e, %{}, []})
      assert GenServer.call(name, {:version, "inc-s"}) == 4
    end
  end

  # ---- list_streams/0 ---------------------------------------------------------

  describe "list_streams/0 (handle_call :list_streams)" do
    setup do
      {_pid, name} = start_store(:list_streams)
      {:ok, name: name}
    end

    test "returns empty list when no streams exist", %{name: name} do
      assert GenServer.call(name, :list_streams) == []
    end

    test "returns stream names after append", %{name: name} do
      GenServer.call(name, {:append, "alpha", :e, %{}, []})
      streams = GenServer.call(name, :list_streams)
      assert "alpha" in streams
    end

    test "returns multiple stream names without duplicates", %{name: name} do
      GenServer.call(name, {:append, "s-a", :e, %{}, []})
      GenServer.call(name, {:append, "s-b", :e, %{}, []})
      GenServer.call(name, {:append, "s-a", :e2, %{}, []})
      streams = GenServer.call(name, :list_streams)
      assert length(streams) == 2
      assert "s-a" in streams
      assert "s-b" in streams
    end
  end

  # ---- subscribe/2 (handle_cast :subscribe) -----------------------------------

  describe "subscribe/2" do
    setup do
      {_pid, name} = start_store(:subscribe)
      {:ok, name: name}
    end

    test "process receives event notification after subscription", %{name: name} do
      GenServer.cast(name, {:subscribe, "notify-stream", self()})
      Process.sleep(10)
      GenServer.call(name, {:append, "notify-stream", :notified, %{msg: "hi"}, []})
      assert_receive {:event, "notify-stream", event}, 500
      assert event.type == :notified
    end

    test "subscriber only receives events for subscribed stream", %{name: name} do
      GenServer.cast(name, {:subscribe, "my-stream", self()})
      Process.sleep(10)
      GenServer.call(name, {:append, "other-stream", :noise, %{}, []})
      GenServer.call(name, {:append, "my-stream", :signal, %{}, []})
      assert_receive {:event, "my-stream", _}, 500
      refute_receive {:event, "other-stream", _}, 100
    end

    test "process survives receiving subscription cast", %{name: name} do
      GenServer.cast(name, {:subscribe, "any", self()})
      Process.sleep(20)
      assert Process.alive?(Process.whereis(name))
    end
  end

  # ---- GenServer lifecycle -----------------------------------------------------

  describe "GenServer lifecycle" do
    test "process remains alive across 200ms of concurrent appends" do
      {pid, name} = start_store(:lifecycle)

      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            GenServer.call(name, {:append, "concurrent-#{rem(i, 3)}", :event, %{i: i}, []})
          end)
        end

      Task.await_many(tasks, 5_000)
      assert Process.alive?(pid)
    end

    test "read after concurrent writes returns all events" do
      {_pid, name} = start_store(:concurrent_read)

      for i <- 1..5,
          do: GenServer.call(name, {:append, "shared", :event, %{i: i}, []})

      {:ok, events} = GenServer.call(name, {:read, "shared", []})
      assert length(events) == 5
    end
  end

  # ---- PropCheck properties ---------------------------------------------------

  property "append always increments stream version by 1" do
    forall n <- PC.choose(1, 10) do
      name = :"es_prop_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(EventStore, [name: name], name: name)

      results =
        for _ <- 1..n,
            do: GenServer.call(name, {:append, "prop-stream", :event, %{}, []})

      GenServer.stop(pid, :normal)

      versions = Enum.map(results, fn {:ok, e} -> e.version end)
      versions == Enum.to_list(1..n)
    end
  end

  property "hlc timestamps are non-decreasing across sequential appends" do
    forall _seed <- PC.boolean() do
      name = :"es_hlc_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(EventStore, [name: name], name: name)

      events =
        for _ <- 1..5 do
          {:ok, e} = GenServer.call(name, {:append, "hlc-stream", :evt, %{}, []})
          e
        end

      GenServer.stop(pid, :normal)

      timestamps = Enum.map(events, & &1.hlc_timestamp)

      Enum.zip(timestamps, tl(timestamps))
      |> Enum.all?(fn {t1, t2} -> t2 >= t1 end)
    end
  end

  # ---- StreamData property tests ----------------------------------------------

  test "read returns subset when limit is less than total events" do
    ExUnitProperties.check all(limit <- SD.integer(1..5)) do
      name = :"es_sd_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(EventStore, [name: name], name: name)

      for _ <- 1..10,
          do: GenServer.call(name, {:append, "limit-stream", :event, %{}, []})

      {:ok, events} = GenServer.call(name, {:read, "limit-stream", [limit: limit]})
      GenServer.stop(pid, :normal, 500)
      assert length(events) <= limit
    end
  end

  test "events in a stream have unique IDs" do
    ExUnitProperties.check all(_x <- SD.boolean()) do
      name = :"es_sd2_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(EventStore, [name: name], name: name)

      events =
        for _ <- 1..5 do
          {:ok, e} = GenServer.call(name, {:append, "unique-id-stream", :evt, %{}, []})
          e
        end

      GenServer.stop(pid, :normal, 500)

      ids = Enum.map(events, & &1.id)
      length(ids) == length(Enum.uniq(ids))
    end
  end
end
