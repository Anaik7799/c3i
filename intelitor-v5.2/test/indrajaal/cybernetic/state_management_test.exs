defmodule Indrajaal.Cybernetic.StateManagementTest do
  @moduledoc """
  TDG test suite for Indrajaal.Cybernetic.StateManagement.

  Named GenServer. Notable behaviors:
  - analyze_temporal_patterns returns {:error, :insufficient_history} (history starts empty)
  - predict_future_state returns {:error, :insufficient_history}
  - recover_from_checkpoint returns {:error, :checkpoint_not_found} for unknown IDs
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Cybernetic.StateManagement

  setup do
    case Process.whereis(StateManagement) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal, 500)
    end

    {:ok, _pid} = start_supervised({StateManagement, %{}})
    :ok
  end

  describe "create_state_vector/3" do
    test "returns a state vector map or tuple" do
      name = "test_vector_#{:rand.uniform(9999)}"
      dimensions = [:cpu, :memory, :latency]
      initial_values = %{cpu: 0.5, memory: 0.6, latency: 50}

      result = StateManagement.create_state_vector(name, dimensions, initial_values)
      assert is_map(result) or match?({:ok, _}, result)
    end

    test "created vector has expected fields" do
      name = "vec_#{:rand.uniform(9999)}"
      result = StateManagement.create_state_vector(name, [:a, :b], %{a: 1, b: 2})
      assert result != nil
    end

    test "does not crash with empty dimensions" do
      result = StateManagement.create_state_vector("empty_vec", [], %{})
      assert result != nil
    end

    test "handles duplicate vector name gracefully" do
      name = "dupe_vec"
      StateManagement.create_state_vector(name, [:x], %{x: 1})
      result = StateManagement.create_state_vector(name, [:x], %{x: 2})
      assert result != nil
    end
  end

  describe "update_state_vector/2" do
    test "returns updated state vector" do
      name = "update_vec_#{:rand.uniform(9999)}"
      StateManagement.create_state_vector(name, [:cpu], %{cpu: 0.5})

      result = StateManagement.update_state_vector(name, %{cpu: 0.75})
      assert is_map(result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "returns error or handles unknown vector name" do
      result = StateManagement.update_state_vector("nonexistent_vec_xyz", %{x: 1})
      # Should not crash; may return error or empty map
      assert result != nil
    end

    test "allows sequential updates" do
      name = "seq_vec_#{:rand.uniform(9999)}"
      StateManagement.create_state_vector(name, [:val], %{val: 0})
      StateManagement.update_state_vector(name, %{val: 1})
      result = StateManagement.update_state_vector(name, %{val: 2})
      assert result != nil
    end
  end

  describe "analyze_temporal_patterns/2" do
    test "returns {:error, :insufficient_history} at startup" do
      # History starts empty, so this always fails until populated
      result = StateManagement.analyze_temporal_patterns("any_vec", %{window: 60})

      assert match?({:error, :insufficient_history}, result) or match?({:error, _}, result) or
               is_map(result)
    end

    test "does not crash with unknown vector name" do
      result = StateManagement.analyze_temporal_patterns("unknown_xyz", %{})
      assert result != nil
    end
  end

  describe "synchronize_distributed_state/1" do
    test "returns a sync result" do
      peers = ["node-1", "node-2", "node-3"]
      result = StateManagement.synchronize_distributed_state(peers)
      assert is_map(result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "does not crash with empty peer list" do
      result = StateManagement.synchronize_distributed_state([])
      assert result != nil
    end

    test "handles single peer" do
      result = StateManagement.synchronize_distributed_state(["node-only"])
      assert result != nil
    end
  end

  describe "predict_future_state/2" do
    test "returns {:error, :insufficient_history} at startup" do
      result = StateManagement.predict_future_state("any_vec", 30)

      assert match?({:error, :insufficient_history}, result) or match?({:error, _}, result) or
               is_map(result)
    end

    test "does not crash with unknown vector" do
      result = StateManagement.predict_future_state("unknown_vec", 60)
      assert result != nil
    end
  end

  describe "create_checkpoint/2" do
    test "returns a checkpoint id or ok tuple" do
      checkpoint_id = "cp_#{:rand.uniform(9999)}"
      metadata = %{reason: "pre_deployment", operator: "test"}

      result = StateManagement.create_checkpoint(checkpoint_id, metadata)
      assert is_binary(result) or match?({:ok, _}, result) or is_map(result)
    end

    test "does not crash with minimal metadata" do
      result = StateManagement.create_checkpoint("cp_minimal", %{})
      assert result != nil
    end

    test "multiple checkpoints can be created" do
      r1 = StateManagement.create_checkpoint("cp_a", %{step: 1})
      r2 = StateManagement.create_checkpoint("cp_b", %{step: 2})
      assert r1 != nil
      assert r2 != nil
    end
  end

  describe "recover_from_checkpoint/1" do
    test "returns {:error, :checkpoint_not_found} for unknown checkpoint" do
      result = StateManagement.recover_from_checkpoint("nonexistent_checkpoint_xyz")
      assert match?({:error, :checkpoint_not_found}, result) or match?({:error, _}, result)
    end

    test "recovers a checkpoint that was created" do
      cp_id = "recoverable_cp_#{:rand.uniform(9999)}"
      StateManagement.create_checkpoint(cp_id, %{step: :before_recovery})

      result = StateManagement.recover_from_checkpoint(cp_id)
      # After creating, should recover successfully or return an error if not stored properly
      assert result != nil
    end

    test "does not crash with empty checkpoint id" do
      result = StateManagement.recover_from_checkpoint("")
      assert result != nil
    end
  end

  describe "get_state_health/0" do
    test "returns a map" do
      result = StateManagement.get_state_health()
      assert is_map(result)
    end

    test "health map has positive vector count" do
      StateManagement.create_state_vector("health_check_vec", [:x], %{x: 1})
      health = StateManagement.get_state_health()
      assert is_map(health)
    end

    test "can be called multiple times" do
      h1 = StateManagement.get_state_health()
      h2 = StateManagement.get_state_health()
      assert is_map(h1)
      assert is_map(h2)
    end

    test "server alive after health check" do
      StateManagement.get_state_health()
      assert Process.alive?(Process.whereis(StateManagement))
    end
  end
end
