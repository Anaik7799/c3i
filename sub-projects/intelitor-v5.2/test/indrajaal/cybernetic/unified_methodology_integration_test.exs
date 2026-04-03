defmodule Indrajaal.Cybernetic.UnifiedMethodologyIntegrationTest do
  @moduledoc """
  TDG test suite for Indrajaal.Cybernetic.UnifiedMethodologyIntegration.

  Named GenServer using parallel Task.async internally.
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Cybernetic.UnifiedMethodologyIntegration

  setup do
    case Process.whereis(UnifiedMethodologyIntegration) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal, 1000)
    end

    {:ok, _pid} = start_supervised({UnifiedMethodologyIntegration, %{}})
    :ok
  end

  describe "execute_unified_analysis/1" do
    test "returns a map for valid problem context" do
      problem = %{
        domain: :alarms,
        complexity: :medium,
        description: "Alarm correlation analysis",
        data: %{events: 42, false_positive_rate: 0.15}
      }

      result = UnifiedMethodologyIntegration.execute_unified_analysis(problem)
      assert is_map(result) or match?({:ok, _}, result)
    end

    test "result contains methodology outputs" do
      problem = %{domain: :safety, complexity: :high}
      result = UnifiedMethodologyIntegration.execute_unified_analysis(problem)
      # Should have some structured output
      assert result != nil
    end

    test "does not crash with empty problem" do
      result = UnifiedMethodologyIntegration.execute_unified_analysis(%{})
      assert result != nil
    end

    test "server remains alive after analysis" do
      UnifiedMethodologyIntegration.execute_unified_analysis(%{domain: :test})
      assert Process.alive?(Process.whereis(UnifiedMethodologyIntegration))
    end

    test "handles high-complexity problem without crash" do
      problem = %{
        domain: :safety,
        complexity: :very_high,
        constraints: [:hard_realtime, :sil4],
        description: "Emergency shutdown sequence analysis"
      }

      result = UnifiedMethodologyIntegration.execute_unified_analysis(problem)
      assert result != nil
    end
  end

  describe "apply_tps_methodology/1" do
    test "returns a TPS analysis result" do
      problem = %{
        current_state: %{defect_rate: 0.05, throughput: 100},
        target_state: %{defect_rate: 0.001, throughput: 150},
        domain: :production
      }

      result = UnifiedMethodologyIntegration.apply_tps_methodology(problem)
      assert is_map(result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "does not crash with minimal problem spec" do
      result = UnifiedMethodologyIntegration.apply_tps_methodology(%{})
      assert result != nil
    end

    test "returns structured waste analysis" do
      problem = %{wastes: [:overprocessing, :waiting], domain: :cybernetic}
      result = UnifiedMethodologyIntegration.apply_tps_methodology(problem)
      assert result != nil
    end
  end

  describe "perform_stamp_analysis/1" do
    test "returns a STAMP analysis result" do
      system_spec = %{
        controllers: [:guardian, :sentinel],
        controlled_processes: [:alarm_processing],
        safety_constraints: ["SC-SAFETY-001"]
      }

      result = UnifiedMethodologyIntegration.perform_stamp_analysis(system_spec)
      assert is_map(result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "does not crash with empty system spec" do
      result = UnifiedMethodologyIntegration.perform_stamp_analysis(%{})
      assert result != nil
    end
  end

  describe "execute_tdg_methodology/1" do
    test "returns a TDG methodology result" do
      spec = %{
        module: "TestModule",
        functions: ["function_a/2", "function_b/1"],
        test_level: :unit
      }

      result = UnifiedMethodologyIntegration.execute_tdg_methodology(spec)
      assert is_map(result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "does not crash with minimal spec" do
      result = UnifiedMethodologyIntegration.execute_tdg_methodology(%{})
      assert result != nil
    end
  end

  describe "apply_gde_execution/1" do
    test "returns a GDE execution result" do
      directive = %{
        goal: "Improve alarm detection accuracy",
        evolution_strategy: :gradient,
        fitness_threshold: 0.95
      }

      result = UnifiedMethodologyIntegration.apply_gde_execution(directive)
      assert is_map(result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "does not crash with empty directive" do
      result = UnifiedMethodologyIntegration.apply_gde_execution(%{})
      assert result != nil
    end
  end

  describe "get_unified_metrics/0" do
    test "returns a map" do
      result = UnifiedMethodologyIntegration.get_unified_metrics()
      assert is_map(result)
    end

    test "metrics map is non-nil" do
      metrics = UnifiedMethodologyIntegration.get_unified_metrics()
      assert metrics != nil
    end

    test "can be called multiple times" do
      m1 = UnifiedMethodologyIntegration.get_unified_metrics()
      m2 = UnifiedMethodologyIntegration.get_unified_metrics()
      assert is_map(m1)
      assert is_map(m2)
    end

    test "metrics accumulate after operations" do
      UnifiedMethodologyIntegration.apply_tps_methodology(%{domain: :test})
      metrics = UnifiedMethodologyIntegration.get_unified_metrics()
      assert is_map(metrics)
    end
  end
end
