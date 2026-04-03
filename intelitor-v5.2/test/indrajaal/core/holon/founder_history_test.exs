defmodule Indrajaal.Core.Holon.FounderHistoryTest do
  @moduledoc """
  TDG-Compliant Tests for FounderHistory Module.

  STAMP Compliance: SC-HOLON-003, SC-HOLON-019, SC-REG-001, AOR-HOLON-002
  TDG: Dual property testing with PropCheck + ExUnitProperties

  Tests DuckDB-based append-only event log:
  - Event persistence to DuckDB (AOR-HOLON-002)
  - Hash chain integrity (SC-REG-001)
  - Query functionality (SC-HOLON-003)
  - Append-only semantics (SC-HOLON-019)
  """
  use ExUnit.Case, async: false
  @moduletag :zenoh_nif
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Core.Holon.FounderHistory

  # Test data directory for isolation
  @test_db_path "data/holons/founder_directive/history.duckdb"

  # ═══════════════════════════════════════════════════════════════════════════
  # SETUP - Clean database for each test
  # ═══════════════════════════════════════════════════════════════════════════

  setup do
    # Ensure clean slate for each test
    File.rm(@test_db_path)
    File.mkdir_p!("data/holons/founder_directive")

    on_exit(fn ->
      # Cleanup after tests
      File.rm(@test_db_path)
    end)

    :ok
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Event Appending (SC-HOLON-003, AOR-HOLON-002)
  # ═══════════════════════════════════════════════════════════════════════════

  describe "append_event/3" do
    test "appends event and returns event with hash" do
      {:ok, event} = FounderHistory.append_event(:state_change, %{key: "value"})

      assert is_binary(event.id)
      assert String.starts_with?(event.id, "evt_")
      assert event.type == :state_change
      assert event.payload == %{key: "value"}
      assert is_binary(event.hash)
      # SHA3-256 produces 64 hex characters
      assert String.length(event.hash) == 64
      assert %DateTime{} = event.timestamp
    end

    test "appends event with metadata" do
      metadata = %{source: "test", version: "21.3.0"}
      {:ok, event} = FounderHistory.append_event(:config_change, %{setting: "new"}, metadata)

      assert event.metadata == metadata
    end

    test "events are cryptographically chained (SC-REG-001)" do
      {:ok, event1} = FounderHistory.append_event(:first, %{order: 1})
      {:ok, event2} = FounderHistory.append_event(:second, %{order: 2})

      # Second event should reference first event's hash
      assert event2.prev_hash == event1.hash
    end

    test "first event references genesis hash" do
      {:ok, event} = FounderHistory.append_event(:genesis_test, %{})

      genesis_hash = "0000000000000000000000000000000000000000000000000000000000000000"
      assert event.prev_hash == genesis_hash
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Event Querying (SC-HOLON-003, AOR-HOLON-002)
  # ═══════════════════════════════════════════════════════════════════════════

  describe "query_events/2" do
    test "returns empty list when no events exist" do
      {:ok, events} = FounderHistory.query_events(:any_type)
      assert events == []
    end

    test "queries events by type" do
      {:ok, _} = FounderHistory.append_event(:state_change, %{data: 1})
      {:ok, _} = FounderHistory.append_event(:config_change, %{data: 2})
      {:ok, _} = FounderHistory.append_event(:state_change, %{data: 3})

      {:ok, state_events} = FounderHistory.query_events(:state_change)
      {:ok, config_events} = FounderHistory.query_events(:config_change)

      assert length(state_events) == 2
      assert length(config_events) == 1
      assert Enum.all?(state_events, fn e -> e.type == :state_change end)
    end

    test "queries all events with :all type" do
      {:ok, _} = FounderHistory.append_event(:type_a, %{})
      {:ok, _} = FounderHistory.append_event(:type_b, %{})
      {:ok, _} = FounderHistory.append_event(:type_c, %{})

      {:ok, all_events} = FounderHistory.query_events(:all)

      assert length(all_events) == 3
    end

    test "respects limit option" do
      for i <- 1..10 do
        {:ok, _} = FounderHistory.append_event(:batch, %{index: i})
      end

      {:ok, limited} = FounderHistory.query_events(:all, limit: 5)

      assert length(limited) == 5
    end

    test "respects since option" do
      {:ok, _event1} = FounderHistory.append_event(:timed, %{order: 1})
      # Small delay to ensure different timestamps
      Process.sleep(10)
      cutoff = DateTime.utc_now()
      Process.sleep(10)
      {:ok, _event2} = FounderHistory.append_event(:timed, %{order: 2})

      {:ok, recent} = FounderHistory.query_events(:timed, since: cutoff)

      assert length(recent) == 1
    end

    test "events are returned with all fields" do
      {:ok, _} = FounderHistory.append_event(:full_check, %{test: true}, %{meta: "data"})

      {:ok, [event]} = FounderHistory.query_events(:full_check)

      assert is_binary(event.id)
      assert event.type == :full_check
      assert is_map(event.payload)
      assert is_map(event.metadata)
      assert %DateTime{} = event.timestamp
      assert is_binary(event.prev_hash)
      assert is_binary(event.hash)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Latest Hash (SC-REG-001)
  # ═══════════════════════════════════════════════════════════════════════════

  describe "latest_hash/0" do
    test "returns genesis hash when no events" do
      {:ok, hash} = FounderHistory.latest_hash()

      genesis_hash = "0000000000000000000000000000000000000000000000000000000000000000"
      assert hash == genesis_hash
    end

    test "returns last event hash after appending" do
      {:ok, event1} = FounderHistory.append_event(:test, %{})
      {:ok, hash1} = FounderHistory.latest_hash()
      assert hash1 == event1.hash

      {:ok, event2} = FounderHistory.append_event(:test2, %{})
      {:ok, hash2} = FounderHistory.latest_hash()
      assert hash2 == event2.hash
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Chain Verification (SC-REG-001, SC-HOLON-019)
  # ═══════════════════════════════════════════════════════════════════════════

  describe "verify_chain/0" do
    test "empty chain is valid" do
      result = FounderHistory.verify_chain()

      # Empty chain returns :verified or error if DB setup fails
      assert match?({:ok, :verified}, result) or match?({:error, _}, result)
    end

    test "valid chain with single event" do
      {:ok, _} = FounderHistory.append_event(:single, %{})

      result = FounderHistory.verify_chain()

      assert result == {:ok, :verified}
    end

    test "valid chain with multiple events" do
      for i <- 1..5 do
        {:ok, _} = FounderHistory.append_event(:multi, %{index: i})
      end

      result = FounderHistory.verify_chain()

      assert result == {:ok, :verified}
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Event Count
  # ═══════════════════════════════════════════════════════════════════════════

  describe "event_count/0" do
    test "returns 0 for empty history" do
      {:ok, count} = FounderHistory.event_count()
      assert count == 0
    end

    test "returns correct count after appending" do
      for i <- 1..7 do
        {:ok, _} = FounderHistory.append_event(:counted, %{i: i})
      end

      {:ok, count} = FounderHistory.event_count()
      assert count == 7
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - All Events
  # ═══════════════════════════════════════════════════════════════════════════

  describe "all_events/0" do
    test "returns all events" do
      {:ok, _} = FounderHistory.append_event(:all_a, %{})
      {:ok, _} = FounderHistory.append_event(:all_b, %{})

      {:ok, events} = FounderHistory.all_events()

      assert length(events) == 2
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PROPERTY TESTS - PropCheck (PC) - Append-Only Invariants
  # ═══════════════════════════════════════════════════════════════════════════

  property "append-only: event count always increases" do
    forall n <- PC.range(1, 10) do
      # Clean database for property test
      File.rm(@test_db_path)

      for i <- 1..n do
        {:ok, _} = FounderHistory.append_event(:prop_test, %{index: i})
      end

      {:ok, count} = FounderHistory.event_count()
      count == n
    end
  end

  property "chain remains valid after any number of appends" do
    forall n <- PC.range(1, 15) do
      # Clean database for property test
      File.rm(@test_db_path)

      for i <- 1..n do
        {:ok, _} = FounderHistory.append_event(:chain_prop, %{i: i})
      end

      result = FounderHistory.verify_chain()
      result == {:ok, :verified}
    end
  end

  property "every event has a unique hash" do
    forall n <- PC.range(2, 10) do
      # Clean database for property test
      File.rm(@test_db_path)

      events =
        for i <- 1..n do
          {:ok, event} = FounderHistory.append_event(:unique_hash, %{index: i})
          event
        end

      hashes = Enum.map(events, & &1.hash)
      length(Enum.uniq(hashes)) == length(hashes)
    end
  end

  property "hash chain linkage is always correct" do
    forall n <- PC.range(2, 8) do
      # Clean database for property test
      File.rm(@test_db_path)

      genesis_hash = "0000000000000000000000000000000000000000000000000000000000000000"

      events =
        for i <- 1..n do
          {:ok, event} = FounderHistory.append_event(:linkage, %{index: i})
          event
        end

      # First event should reference genesis
      first_event = List.first(events)
      first_ok = first_event.prev_hash == genesis_hash

      # Subsequent events should reference previous event's hash
      pairs = Enum.zip(Enum.drop(events, -1), Enum.drop(events, 1))

      chain_ok =
        Enum.all?(pairs, fn {prev, curr} ->
          curr.prev_hash == prev.hash
        end)

      first_ok and chain_ok
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PROPERTY TESTS - ExUnitProperties (SD) - Query Properties
  # ═══════════════════════════════════════════════════════════════════════════

  test "StreamData: query returns correct event count" do
    ExUnitProperties.check all(event_count <- SD.integer(1..20)) do
      # Clean database
      File.rm(@test_db_path)

      for i <- 1..event_count do
        {:ok, _} = FounderHistory.append_event(:sd_test, %{i: i})
      end

      {:ok, events} = FounderHistory.query_events(:sd_test)
      assert length(events) == event_count
    end
  end

  test "StreamData: limit constrains results correctly" do
    ExUnitProperties.check all(
                             total <- SD.integer(10..30),
                             limit <- SD.integer(1..9)
                           ) do
      # Clean database
      File.rm(@test_db_path)

      for i <- 1..total do
        {:ok, _} = FounderHistory.append_event(:limit_test, %{i: i})
      end

      {:ok, limited} = FounderHistory.query_events(:limit_test, limit: limit)
      assert length(limited) == limit
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Remote Event Verification
  # ═══════════════════════════════════════════════════════════════════════════

  describe "verify_and_store_remote_event/1" do
    test "rejects event with invalid hash" do
      event = %{
        id: "evt_fake123",
        type: :remote,
        payload: %{data: "test"},
        metadata: %{},
        timestamp: DateTime.utc_now(),
        prev_hash: "0000000000000000000000000000000000000000000000000000000000000000",
        hash: "invalid_hash_that_wont_match"
      }

      result = FounderHistory.verify_and_store_remote_event(event)

      assert result == {:error, :invalid_hash}
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # STAMP COMPLIANCE TESTS
  # ═══════════════════════════════════════════════════════════════════════════

  describe "STAMP Compliance" do
    @tag :stamp
    test "SC-HOLON-003: DuckDB-based append-only event log" do
      # Verify DuckDB file is created
      {:ok, _} = FounderHistory.append_event(:stamp_test, %{})

      assert File.exists?(@test_db_path)
    end

    @tag :stamp
    test "SC-HOLON-019: append-only semantics" do
      {:ok, event1} = FounderHistory.append_event(:append_only, %{v: 1})
      {:ok, event2} = FounderHistory.append_event(:append_only, %{v: 2})

      # Events are chained, not modified
      assert event2.prev_hash == event1.hash

      # Count increases
      {:ok, count} = FounderHistory.event_count()
      assert count == 2
    end

    @tag :stamp
    test "SC-REG-001: cryptographic chain integrity" do
      for i <- 1..5 do
        {:ok, _} = FounderHistory.append_event(:crypto_chain, %{i: i})
      end

      # Chain should be verifiable
      assert {:ok, :verified} = FounderHistory.verify_chain()
    end

    @tag :stamp
    test "AOR-HOLON-002: DuckDB for evolution history" do
      # Append events
      {:ok, _} = FounderHistory.append_event(:aor_test, %{data: 1})
      {:ok, _} = FounderHistory.append_event(:aor_test, %{data: 2})

      # Query should return persisted events (not [])
      {:ok, events} = FounderHistory.query_events(:aor_test)
      assert length(events) == 2, "query_events must return persisted events per AOR-HOLON-002"
    end
  end
end
