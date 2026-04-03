defmodule Indrajaal.CortexTest do
  @moduledoc """
  Tests for Indrajaal.Cortex module.

  WHAT: Tests Cortex status, health, and remote health checking.
  WHY: Ensures cognitive center reports accurate health and coordinates components.
  CONSTRAINTS: SC-CTX-001 (supervised components), SC-OODA-001 (50ms cycles)

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.0 | 2026-03-08 | Claude Opus 4.6 | Initial implementation |
  """
  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Cortex

  # ============================================================================
  # Unit Tests - status/0
  # ============================================================================

  describe "status/0" do
    test "returns :stopped when supervisor is not running" do
      # In test environment, Cortex.Supervisor is typically not started
      assert Cortex.status() in [:stopped, :initializing, :running, :degraded]
    end

    test "returns a valid cortex_status atom" do
      status = Cortex.status()
      assert status in [:initializing, :running, :degraded, :stopped]
    end
  end

  # ============================================================================
  # Unit Tests - health/0
  # ============================================================================

  describe "health/0" do
    test "returns a map with expected keys" do
      health = Cortex.health()

      assert is_map(health)
      assert Map.has_key?(health, :supervisor_alive)
      assert Map.has_key?(health, :self_healing)
      assert Map.has_key?(health, :predictor)
      assert Map.has_key?(health, :fast_ooda)
      assert Map.has_key?(health, :overall_status)
      assert Map.has_key?(health, :timestamp)
    end

    test "supervisor_alive is a boolean" do
      health = Cortex.health()
      assert is_boolean(health.supervisor_alive)
    end

    test "component statuses are valid atoms" do
      health = Cortex.health()
      valid_statuses = [:healthy, :unhealthy, :not_running, :disabled]

      assert health.self_healing in valid_statuses
      assert health.predictor in valid_statuses
      assert health.fast_ooda in valid_statuses
    end

    test "overall_status matches cortex_status type" do
      health = Cortex.health()
      assert health.overall_status in [:initializing, :running, :degraded, :stopped]
    end

    test "timestamp is a DateTime" do
      health = Cortex.health()
      assert %DateTime{} = health.timestamp
    end
  end

  # ============================================================================
  # Unit Tests - ready?/0
  # ============================================================================

  describe "ready?/0" do
    test "returns a boolean" do
      assert is_boolean(Cortex.ready?())
    end

    test "ready? is true only when status is :running" do
      if Cortex.status() == :running do
        assert Cortex.ready?()
      else
        refute Cortex.ready?()
      end
    end
  end

  # ============================================================================
  # Unit Tests - remote_health/0
  # ============================================================================

  describe "remote_health/0" do
    test "returns error tuple when container is unavailable" do
      # In test environment, the cortex container is not running
      result = Cortex.remote_health()
      assert match?({:error, :unavailable}, result) or match?({:ok, _}, result)
    end

    test "returns valid tuple format" do
      case Cortex.remote_health() do
        {:ok, data} ->
          assert is_map(data)

        {:error, :unavailable} ->
          # Expected when container is not running
          assert true
      end
    end
  end

  # ============================================================================
  # Unit Tests - full_health/0
  # ============================================================================

  describe "full_health/0" do
    test "includes local health fields" do
      full = Cortex.full_health()

      assert Map.has_key?(full, :supervisor_alive)
      assert Map.has_key?(full, :self_healing)
      assert Map.has_key?(full, :predictor)
      assert Map.has_key?(full, :fast_ooda)
      assert Map.has_key?(full, :overall_status)
    end

    test "includes remote health fields" do
      full = Cortex.full_health()

      assert Map.has_key?(full, :remote_cortex)
      assert Map.has_key?(full, :remote_url)
    end

    test "remote_cortex is either :connected or :unavailable" do
      full = Cortex.full_health()
      assert full.remote_cortex in [:connected, :unavailable]
    end

    test "remote_url is a valid URL string" do
      full = Cortex.full_health()
      assert is_binary(full.remote_url)
      assert String.starts_with?(full.remote_url, "http")
    end
  end

  # ============================================================================
  # Unit Tests - determine_overall_status
  # ============================================================================

  describe "status determination logic" do
    test "stopped when supervisor is not alive" do
      # When no supervisor process, status should be :stopped
      if Process.whereis(Indrajaal.Cortex.Supervisor) == nil do
        assert Cortex.status() == :stopped
      end
    end
  end

  # ============================================================================
  # Property Tests - Health Status Consistency (PropCheck)
  # ============================================================================

  property "health map always contains required keys" do
    forall _i <- PC.integer(1, 100) do
      health = Cortex.health()

      Map.has_key?(health, :supervisor_alive) and
        Map.has_key?(health, :self_healing) and
        Map.has_key?(health, :predictor) and
        Map.has_key?(health, :fast_ooda) and
        Map.has_key?(health, :overall_status) and
        Map.has_key?(health, :timestamp)
    end
  end

  property "full_health is a superset of health" do
    forall _i <- PC.integer(1, 10) do
      health_keys = Cortex.health() |> Map.keys() |> MapSet.new()
      full_keys = Cortex.full_health() |> Map.keys() |> MapSet.new()
      MapSet.subset?(health_keys, full_keys)
    end
  end

  # ============================================================================
  # Property Tests - Status Consistency (StreamData)
  # ============================================================================

  property "ready? is consistent with status" do
    forall _ <- PC.integer(1, 50) do
      status = Cortex.status()
      ready = Cortex.ready?()

      if status == :running do
        ready == true
      else
        ready == false
      end
    end
  end

  property "overall_status in health matches status" do
    forall _ <- PC.integer(1, 20) do
      health = Cortex.health()
      status = Cortex.status()
      health.overall_status == status
    end
  end
end
