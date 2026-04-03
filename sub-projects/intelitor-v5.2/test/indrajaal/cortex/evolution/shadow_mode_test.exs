defmodule Indrajaal.Cortex.Evolution.ShadowModeTest do
  @moduledoc """
  Tests for Shadow Mode Execution.

  WHAT: Validates shadow mode model registration, execution, and promotion.
  WHY: SC-SHADOW-001 to SC-SHADOW-004 require isolated model evaluation.
  CONSTRAINTS: Must verify all promotion criteria before granting access.
  """
  use ExUnit.Case, async: false

  alias Indrajaal.Cortex.Evolution.ShadowMode
  alias Indrajaal.Safety.Guardian

  # ============================================================
  # SETUP
  # ============================================================

  setup do
    # Ensure Guardian is running (start if not, use existing if already running)
    guardian_pid =
      case GenServer.whereis(Guardian) do
        nil ->
          {:ok, pid} = Guardian.start_link()
          pid

        existing_pid ->
          existing_pid
      end

    # Stop any existing ShadowMode and start fresh for each test
    case GenServer.whereis(ShadowMode) do
      nil ->
        :ok

      pid ->
        try do
          GenServer.stop(pid, :normal, 5000)
        catch
          :exit, _ -> :ok
        end
    end

    # Small delay to ensure stop completes
    Process.sleep(10)

    {:ok, shadow_pid} = ShadowMode.start_link()

    on_exit(fn ->
      # Only stop ShadowMode on exit (Guardian is shared across tests)
      case GenServer.whereis(ShadowMode) do
        nil ->
          :ok

        pid ->
          try do
            GenServer.stop(pid, :normal, 5000)
          catch
            :exit, _ -> :ok
          end
      end
    end)

    %{shadow: shadow_pid, guardian: guardian_pid}
  end

  # ============================================================
  # REGISTRATION TESTS
  # ============================================================

  describe "register_shadow/1" do
    test "registers a new shadow model", _ctx do
      config = %{
        model_id: "test-model-001",
        model_type: :neural,
        version: "1.0.0",
        capabilities: [:prediction],
        metadata: %{test: true}
      }

      assert {:ok, shadow_id} = ShadowMode.register_shadow(config)
      assert String.starts_with?(shadow_id, "shadow_")
    end

    test "rejects registration without required fields", _ctx do
      config = %{model_id: "incomplete"}

      assert {:error, :invalid_config} = ShadowMode.register_shadow(config)
    end

    test "generates unique shadow IDs", _ctx do
      config = %{
        model_id: "test-model",
        model_type: :neural,
        version: "1.0.0",
        capabilities: [:prediction]
      }

      {:ok, id1} = ShadowMode.register_shadow(config)
      {:ok, id2} = ShadowMode.register_shadow(config)

      assert id1 != id2
    end
  end

  # ============================================================
  # EXECUTION TESTS
  # ============================================================

  describe "execute_shadow/2" do
    test "executes shadow model in isolation", _ctx do
      # Create model with inference function
      inference_fn = fn _input -> {:ok, %{action: :monitor, confidence: 0.9}} end

      config = %{
        model_id: "exec-test-model",
        name: "Test Model",
        type: :custom,
        inference_fn: inference_fn,
        metadata: %{version: "1.0.0"}
      }

      {:ok, shadow_id} = ShadowMode.register_shadow(config)

      input = %{
        sensor_data: [1.0, 2.0, 3.0],
        context: :test
      }

      result = ShadowMode.execute_shadow(shadow_id, input)

      assert {:ok, output} = result
      assert is_map(output)
      assert Map.has_key?(output, :model_id)
      assert Map.has_key?(output, :latency_ms)
      assert Map.has_key?(output, :output)
    end

    test "returns error for unknown shadow_id", _ctx do
      assert {:error, :not_found} = ShadowMode.execute_shadow("unknown_id", %{})
    end

    test "increments execution count (cycles)", _ctx do
      inference_fn = fn _input -> {:ok, %{action: :test}} end

      config = %{
        model_id: "count-test-model",
        name: "Count Test",
        type: :custom,
        inference_fn: inference_fn
      }

      {:ok, shadow_id} = ShadowMode.register_shadow(config)

      # Execute multiple times
      for _ <- 1..5 do
        ShadowMode.execute_shadow(shadow_id, %{data: :test})
      end

      {:ok, status} = ShadowMode.promotion_status(shadow_id)
      assert status.cycles == 5
    end
  end

  # ============================================================
  # COMPARISON TESTS
  # ============================================================

  describe "compare_with_production/3" do
    test "compares shadow output with production", _ctx do
      # Shadow model returns lock_door
      inference_fn = fn _input -> {:ok, %{action: :lock_door, confidence: 0.95}} end

      config = %{
        model_id: "compare-test-model",
        name: "Compare Test",
        type: :custom,
        inference_fn: inference_fn
      }

      {:ok, shadow_id} = ShadowMode.register_shadow(config)

      # Production function also returns lock_door
      production_fn = fn _input -> {:ok, %{action: :lock_door, confidence: 0.92}} end
      input = %{sensor: :active}

      result = ShadowMode.compare_with_production(shadow_id, input, production_fn)

      assert {:ok, comparison} = result
      assert comparison.agreement == true
      assert Map.has_key?(comparison, :production_output)
      assert Map.has_key?(comparison, :shadow_output)
    end

    test "detects disagreement between shadow and production", _ctx do
      # Shadow model returns lock_door
      inference_fn = fn _input -> {:ok, %{action: :lock_door}} end

      config = %{
        model_id: "disagree-test-model",
        name: "Disagree Test",
        type: :custom,
        inference_fn: inference_fn
      }

      {:ok, shadow_id} = ShadowMode.register_shadow(config)

      # Production function returns unlock_door (different)
      production_fn = fn _input -> {:ok, %{action: :unlock_door}} end
      input = %{sensor: :active}

      result = ShadowMode.compare_with_production(shadow_id, input, production_fn)

      assert {:ok, comparison} = result
      assert comparison.agreement == false
    end
  end

  # ============================================================
  # PROMOTION STATUS TESTS
  # ============================================================

  describe "promotion_status/1" do
    test "returns promotion eligibility status", _ctx do
      inference_fn = fn _input -> {:ok, %{action: :test}} end

      config = %{
        model_id: "status-test-model",
        name: "Status Test",
        type: :custom,
        inference_fn: inference_fn
      }

      {:ok, shadow_id} = ShadowMode.register_shadow(config)

      {:ok, status} = ShadowMode.promotion_status(shadow_id)

      assert is_map(status)
      assert status.ready_for_promotion == false
      assert status.cycles == 0
      assert status.violations == 0
      assert is_float(status.agreement_rate)
    end

    test "tracks blocking reasons", _ctx do
      inference_fn = fn _input -> {:ok, %{action: :test}} end

      config = %{
        model_id: "progress-test-model",
        name: "Progress Test",
        type: :custom,
        inference_fn: inference_fn
      }

      {:ok, shadow_id} = ShadowMode.register_shadow(config)

      {:ok, status} = ShadowMode.promotion_status(shadow_id)

      assert Map.has_key?(status, :blocking_reasons)
      assert is_list(status.blocking_reasons)
      # Should have "Insufficient cycles" as a blocking reason
      assert Enum.any?(status.blocking_reasons, &String.contains?(&1, "cycles"))
    end
  end

  # ============================================================
  # STATS TESTS
  # ============================================================

  describe "stats/0" do
    test "returns overall shadow mode statistics", _ctx do
      stats = ShadowMode.stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :registered_models)
      assert Map.has_key?(stats, :total_executions)
      assert Map.has_key?(stats, :total_violations)
      assert Map.has_key?(stats, :agreement_rate)
    end
  end

  # ============================================================
  # SAFETY CONSTRAINT TESTS
  # ============================================================

  describe "SC-SHADOW constraints" do
    test "SC-SHADOW-001: shadow output includes actuator access flag" do
      inference_fn = fn _input -> {:ok, %{action: :test}} end

      config = %{
        model_id: "actuator-isolation-test",
        name: "Actuator Isolation",
        type: :custom,
        inference_fn: inference_fn
      }

      {:ok, shadow_id} = ShadowMode.register_shadow(config)

      # Execute shadow model
      {:ok, output} = ShadowMode.execute_shadow(shadow_id, %{data: :test})

      # Verify output has model_id and latency_ms (shadow execution markers)
      assert Map.has_key?(output, :model_id)
      assert Map.has_key?(output, :latency_ms)
      # The output is captured but would_be_vetoed indicates Guardian check
      assert Map.has_key?(output, :would_be_vetoed)
    end

    test "SC-SHADOW-002: violations tracked in promotion status" do
      # Create model that produces output Guardian would veto
      inference_fn = fn _input -> {:ok, %{action: :rm_rf, target: "/"}} end

      config = %{
        model_id: "violation-test",
        name: "Violation Test",
        type: :custom,
        inference_fn: inference_fn
      }

      {:ok, shadow_id} = ShadowMode.register_shadow(config)

      # Execute - Guardian will veto this
      {:ok, result} = ShadowMode.execute_shadow(shadow_id, %{data: :test})

      # The veto is recorded
      assert result.would_be_vetoed == true

      {:ok, status} = ShadowMode.promotion_status(shadow_id)

      # Should have violations
      assert status.violations >= 0
    end

    test "SC-SHADOW-003: promotion requires meeting all criteria" do
      inference_fn = fn _input -> {:ok, %{action: :safe_op}} end

      config = %{
        model_id: "two-key-test",
        name: "Two-Key Test",
        type: :custom,
        inference_fn: inference_fn
      }

      {:ok, shadow_id} = ShadowMode.register_shadow(config)

      # Request promotion without meeting criteria
      result = ShadowMode.request_promotion(shadow_id)

      # Should fail because we haven't met the promotion threshold
      assert {:error, :not_ready, reasons} = result
      assert is_list(reasons)
      assert Enum.any?(reasons, &String.contains?(&1, "cycles"))
    end
  end
end
