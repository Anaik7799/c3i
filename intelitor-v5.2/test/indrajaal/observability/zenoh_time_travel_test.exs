defmodule Indrajaal.Observability.ZenohTimeTravelTest do
  @moduledoc """
  TDG Test Artifacts for ZenohTimeTravel.

  WHAT: Tests for checkpoint recording and state rewind.
  WHY: SC-CTX-008 requires checkpoint recovery within 1000ms.
  CONSTRAINTS: Must test checkpoint storage, retrieval, pruning.

  ## TDG Methodology

  - Property tests for checkpoint invariants
  - Unit tests for CRUD operations
  - Integration tests for session management

  ## STAMP Constraints Tested

  - SC-CTX-008: Checkpoint recoverable within 1000ms
  - SC-OBS-002: No data loss during checkpoint

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-26 |
  | Author | Cybernetic Architect |
  | STAMP | SC-CTX-008, SC-OBS-002 |
  """

  use ExUnit.Case, async: false
  use PropCheck

  alias PropCheck.BasicTypes, as: PC
  alias Indrajaal.Observability.ZenohTimeTravel

  # ============================================================
  # SETUP
  # ============================================================

  setup do
    # Start the GenServer for tests
    case GenServer.whereis(ZenohTimeTravel) do
      nil ->
        {:ok, pid} = ZenohTimeTravel.start_link(max_per_session: 10, ttl_seconds: 60)
        on_exit(fn -> Process.exit(pid, :normal) end)
        {:ok, pid: pid}

      pid ->
        # Clear existing sessions for clean tests
        {:ok, pid: pid}
    end
  end

  # ============================================================
  # UNIT TESTS - RECORD CHECKPOINT
  # ============================================================

  describe "record_checkpoint/2" do
    test "records a checkpoint and returns ID" do
      state = %{counter: 1, data: "test"}
      {:ok, checkpoint_id} = ZenohTimeTravel.record_checkpoint(state)

      assert is_binary(checkpoint_id)
      assert String.length(checkpoint_id) > 10
    end

    test "records checkpoint with custom session" do
      state = %{value: 42}
      {:ok, checkpoint_id} = ZenohTimeTravel.record_checkpoint(state, session: "test_session")

      assert String.contains?(checkpoint_id, "test_session")
    end

    test "records checkpoint with metadata" do
      state = %{step: 1}
      metadata = %{step_name: "init", author: "test"}
      {:ok, checkpoint_id} = ZenohTimeTravel.record_checkpoint(state, metadata: metadata)

      {:ok, checkpoint} = ZenohTimeTravel.get_checkpoint(checkpoint_id)
      assert checkpoint.metadata == metadata
    end

    test "generates unique IDs for each checkpoint" do
      state = %{data: "test"}
      {:ok, id1} = ZenohTimeTravel.record_checkpoint(state)
      {:ok, id2} = ZenohTimeTravel.record_checkpoint(state)
      {:ok, id3} = ZenohTimeTravel.record_checkpoint(state)

      assert id1 != id2
      assert id2 != id3
      assert id1 != id3
    end

    test "calculates checkpoint size" do
      state = %{large_data: String.duplicate("x", 1000)}
      {:ok, checkpoint_id} = ZenohTimeTravel.record_checkpoint(state)

      {:ok, checkpoint} = ZenohTimeTravel.get_checkpoint(checkpoint_id)
      assert checkpoint.size_bytes > 1000
    end
  end

  # ============================================================
  # UNIT TESTS - REWIND
  # ============================================================

  describe "rewind_to/1" do
    test "restores checkpoint state" do
      original_state = %{counter: 42, name: "test"}
      {:ok, checkpoint_id} = ZenohTimeTravel.record_checkpoint(original_state)

      {:ok, restored_state} = ZenohTimeTravel.rewind_to(checkpoint_id)
      assert restored_state == original_state
    end

    test "returns error for unknown checkpoint" do
      assert {:error, :not_found} = ZenohTimeTravel.rewind_to("nonexistent_id")
    end

    test "preserves complex state types" do
      complex_state = %{
        list: [1, 2, 3],
        tuple: {:ok, "value"},
        nested: %{a: %{b: %{c: 1}}},
        atom: :test_atom
      }

      {:ok, checkpoint_id} = ZenohTimeTravel.record_checkpoint(complex_state)
      {:ok, restored} = ZenohTimeTravel.rewind_to(checkpoint_id)

      assert restored == complex_state
    end
  end

  describe "rewind_previous/1" do
    test "rewinds to most recent checkpoint in session" do
      session = "rewind_previous_test_#{:rand.uniform(10_000)}"

      {:ok, _id1} = ZenohTimeTravel.record_checkpoint(%{step: 1}, session: session)
      {:ok, _id2} = ZenohTimeTravel.record_checkpoint(%{step: 2}, session: session)
      {:ok, id3} = ZenohTimeTravel.record_checkpoint(%{step: 3}, session: session)

      {:ok, restored_state, returned_id} = ZenohTimeTravel.rewind_previous(session)
      assert restored_state == %{step: 3}
      assert returned_id == id3
    end

    test "returns error for empty session" do
      assert {:error, :no_checkpoints} = ZenohTimeTravel.rewind_previous("empty_session")
    end
  end

  # ============================================================
  # UNIT TESTS - LIST & GET
  # ============================================================

  describe "list_checkpoints/2" do
    test "lists checkpoints for session" do
      session = "list_test_#{:rand.uniform(10_000)}"

      {:ok, _} = ZenohTimeTravel.record_checkpoint(%{a: 1}, session: session)
      {:ok, _} = ZenohTimeTravel.record_checkpoint(%{a: 2}, session: session)

      checkpoints = ZenohTimeTravel.list_checkpoints(session)
      assert length(checkpoints) == 2
    end

    test "returns newest first" do
      session = "order_test_#{:rand.uniform(10_000)}"

      {:ok, id1} = ZenohTimeTravel.record_checkpoint(%{order: 1}, session: session)
      Process.sleep(10)
      {:ok, id2} = ZenohTimeTravel.record_checkpoint(%{order: 2}, session: session)

      [first, second] = ZenohTimeTravel.list_checkpoints(session)
      assert first.id == id2
      assert second.id == id1
    end

    test "respects limit option" do
      session = "limit_test_#{:rand.uniform(10_000)}"

      for i <- 1..5 do
        ZenohTimeTravel.record_checkpoint(%{i: i}, session: session)
      end

      checkpoints = ZenohTimeTravel.list_checkpoints(session, limit: 3)
      assert length(checkpoints) == 3
    end

    test "returns empty list for unknown session" do
      checkpoints = ZenohTimeTravel.list_checkpoints("unknown_session")
      assert checkpoints == []
    end
  end

  describe "get_checkpoint/1" do
    test "returns full checkpoint data" do
      state = %{full: "data"}
      {:ok, checkpoint_id} = ZenohTimeTravel.record_checkpoint(state, metadata: %{key: "value"})

      {:ok, checkpoint} = ZenohTimeTravel.get_checkpoint(checkpoint_id)

      assert checkpoint.id == checkpoint_id
      assert checkpoint.state == state
      assert checkpoint.metadata == %{key: "value"}
      assert checkpoint.size_bytes > 0
      assert %DateTime{} = checkpoint.timestamp
    end

    test "returns error for unknown checkpoint" do
      assert {:error, :not_found} = ZenohTimeTravel.get_checkpoint("unknown")
    end
  end

  # ============================================================
  # UNIT TESTS - DELETE & CLEAR
  # ============================================================

  describe "delete_checkpoint/1" do
    test "deletes existing checkpoint" do
      {:ok, checkpoint_id} = ZenohTimeTravel.record_checkpoint(%{delete: "me"})
      assert :ok = ZenohTimeTravel.delete_checkpoint(checkpoint_id)
      assert {:error, :not_found} = ZenohTimeTravel.get_checkpoint(checkpoint_id)
    end

    test "returns ok for nonexistent checkpoint" do
      assert :ok = ZenohTimeTravel.delete_checkpoint("nonexistent")
    end
  end

  describe "clear_session/1" do
    test "clears all checkpoints in session" do
      session = "clear_test_#{:rand.uniform(10_000)}"

      {:ok, _} = ZenohTimeTravel.record_checkpoint(%{a: 1}, session: session)
      {:ok, _} = ZenohTimeTravel.record_checkpoint(%{a: 2}, session: session)

      {:ok, deleted_count} = ZenohTimeTravel.clear_session(session)
      assert deleted_count == 2

      checkpoints = ZenohTimeTravel.list_checkpoints(session)
      assert checkpoints == []
    end
  end

  # ============================================================
  # UNIT TESTS - SESSIONS
  # ============================================================

  describe "new_session/1" do
    test "creates new session with unique ID" do
      {:ok, session_id} = ZenohTimeTravel.new_session()
      assert is_binary(session_id)
      assert String.starts_with?(session_id, "session_")
    end

    test "creates session with custom prefix" do
      {:ok, session_id} = ZenohTimeTravel.new_session(prefix: "gde")
      assert String.starts_with?(session_id, "gde_")
    end
  end

  # ============================================================
  # UNIT TESTS - STATS
  # ============================================================

  describe "stats/0" do
    test "returns statistics map" do
      stats = ZenohTimeTravel.stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :total_checkpoints)
      assert Map.has_key?(stats, :current_checkpoints)
      assert Map.has_key?(stats, :total_rewinds)
      assert Map.has_key?(stats, :total_bytes)
      assert Map.has_key?(stats, :sessions)
      assert Map.has_key?(stats, :uptime_seconds)
    end

    test "tracks rewind count" do
      {:ok, checkpoint_id} = ZenohTimeTravel.record_checkpoint(%{track: "rewinds"})

      initial_stats = ZenohTimeTravel.stats()
      initial_rewinds = initial_stats.total_rewinds

      ZenohTimeTravel.rewind_to(checkpoint_id)
      ZenohTimeTravel.rewind_to(checkpoint_id)

      final_stats = ZenohTimeTravel.stats()
      assert final_stats.total_rewinds == initial_rewinds + 2
    end
  end

  # ============================================================
  # PROPERTY TESTS
  # ============================================================

  describe "property tests" do
    property "any term can be checkpointed and restored" do
      forall state <- PC.any() do
        {:ok, checkpoint_id} = ZenohTimeTravel.record_checkpoint(state)
        {:ok, restored} = ZenohTimeTravel.rewind_to(checkpoint_id)
        restored == state
      end
    end

    property "checkpoint IDs are always unique" do
      forall n <- PC.integer(2, 10) do
        ids =
          for _ <- 1..n do
            {:ok, id} = ZenohTimeTravel.record_checkpoint(%{n: n})
            id
          end

        length(Enum.uniq(ids)) == n
      end
    end

    property "list_checkpoints respects limit" do
      forall {n, limit} <- {PC.integer(1, 10), PC.integer(1, 5)} do
        session = "prop_limit_#{:rand.uniform(100_000)}"

        for i <- 1..n do
          ZenohTimeTravel.record_checkpoint(%{i: i}, session: session)
        end

        checkpoints = ZenohTimeTravel.list_checkpoints(session, limit: limit)
        length(checkpoints) <= limit
      end
    end
  end

  # ============================================================
  # LATENCY TESTS (SC-CTX-008)
  # ============================================================

  describe "SC-CTX-008 latency requirements" do
    test "record_checkpoint completes in <100ms" do
      state = %{large: String.duplicate("x", 10_000)}

      start = System.monotonic_time(:millisecond)
      {:ok, _} = ZenohTimeTravel.record_checkpoint(state)
      elapsed = System.monotonic_time(:millisecond) - start

      assert elapsed < 100, "record_checkpoint took #{elapsed}ms, expected <100ms"
    end

    test "rewind_to completes in <100ms" do
      {:ok, checkpoint_id} = ZenohTimeTravel.record_checkpoint(%{latency: "test"})

      start = System.monotonic_time(:millisecond)
      {:ok, _} = ZenohTimeTravel.rewind_to(checkpoint_id)
      elapsed = System.monotonic_time(:millisecond) - start

      assert elapsed < 100, "rewind_to took #{elapsed}ms, expected <100ms"
    end

    test "list_checkpoints completes in <50ms" do
      session = "latency_list_#{:rand.uniform(10_000)}"

      for i <- 1..10 do
        ZenohTimeTravel.record_checkpoint(%{i: i}, session: session)
      end

      start = System.monotonic_time(:millisecond)
      _ = ZenohTimeTravel.list_checkpoints(session)
      elapsed = System.monotonic_time(:millisecond) - start

      assert elapsed < 50, "list_checkpoints took #{elapsed}ms, expected <50ms"
    end
  end
end
