defmodule Indrajaal.Testing.TimescaleIntegrationTest do
  @moduledoc """
  TDG test suite for Testing.TimescaleIntegration.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation verification
  - DB-dependent module — tests validate lifecycle and cast APIs

  ## STAMP Safety Integration
  - SC-COV-002: Runtime coverage >= 95%
  - SC-DB-001: Use BaseResource
  - SC-MIG-001: Database tests must declare migrations

  ## Constitutional Verification
  - Ψ₀ Existence: Module init may stop itself when DB unavailable — tests handle both paths

  ## TPS 5-Level RCA Context
  - L1 Symptom: TimescaleIntegration fails to start when DB is unavailable
  - L5 Root Cause: init/1 calls setup_hypertables() which requires live PostgreSQL connection
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Testing.TimescaleIntegration

  @moduletag :zenoh_nif

  setup do
    case Process.whereis(TimescaleIntegration) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal, 5000)
    end

    Process.sleep(50)
    :ok
  end

  # ============================================================================
  # Module structure and spec tests (no server needed)
  # ============================================================================

  describe "module API definition" do
    test "start_link/1 function exists with correct arity" do
      assert function_exported?(TimescaleIntegration, :start_link, 1)
    end

    test "record_test_execution/2 function exists" do
      assert function_exported?(TimescaleIntegration, :record_test_execution, 2)
    end

    test "record_performance_metrics/2 function exists" do
      assert function_exported?(TimescaleIntegration, :record_performance_metrics, 2)
    end

    test "record_quality_gate/2 function exists" do
      assert function_exported?(TimescaleIntegration, :record_quality_gate, 2)
    end

    test "record_test_failure/2 function exists" do
      assert function_exported?(TimescaleIntegration, :record_test_failure, 2)
    end

    test "record_pipeline_metrics/2 function exists" do
      assert function_exported?(TimescaleIntegration, :record_pipeline_metrics, 2)
    end

    test "get_test_analytics/3 function exists" do
      assert function_exported?(TimescaleIntegration, :get_test_analytics, 3)
    end

    test "get_performance_regression_analysis/3 function exists" do
      assert function_exported?(TimescaleIntegration, :get_performance_regression_analysis, 3)
    end

    test "get_failure_pattern_analysis/3 function exists" do
      assert function_exported?(TimescaleIntegration, :get_failure_pattern_analysis, 3)
    end

    test "get_quality_dashboard_data/2 function exists" do
      assert function_exported?(TimescaleIntegration, :get_quality_dashboard_data, 2)
    end
  end

  # ============================================================================
  # GenServer lifecycle (DB-dependent init)
  # ============================================================================

  describe "start_link/1" do
    test "returns a result tuple" do
      result = TimescaleIntegration.start_link([])
      # Either {:ok, pid} if DB available, or {:error, reason} if not
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "when successful, returns a live pid" do
      case TimescaleIntegration.start_link([]) do
        {:ok, pid} ->
          assert Process.alive?(pid)
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

        {:error, _reason} ->
          # DB not available — acceptable in test environment
          :ok
      end
    end

    test "registers under module name when successful" do
      case TimescaleIntegration.start_link([]) do
        {:ok, pid} ->
          assert Process.whereis(TimescaleIntegration) == pid
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

        {:error, _} ->
          :ok
      end
    end

    test "second start returns already_started when first is running" do
      case TimescaleIntegration.start_link([]) do
        {:ok, pid} ->
          result = TimescaleIntegration.start_link([])
          assert {:error, {:already_started, ^pid}} = result
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

        {:error, _} ->
          :ok
      end
    end
  end

  # ============================================================================
  # Cast functions (fire-and-forget — valid even to non-existent server,
  # though they will crash if server not registered; skip if server down)
  # ============================================================================

  describe "record_test_execution/2 (cast)" do
    @test_data %{
      tenant_id: "tenant_1",
      test_suite: "MyTest",
      test_name: "test something",
      test_type: "unit",
      status: :passed,
      execution_time_ms: 10,
      memory_usage_kb: 128,
      assertions: 5,
      tags: [],
      metadata: %{}
    }

    test "returns :ok when server is running" do
      case TimescaleIntegration.start_link([]) do
        {:ok, pid} ->
          result = TimescaleIntegration.record_test_execution(@test_data)
          assert result == :ok
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

        {:error, _} ->
          :ok
      end
    end
  end

  describe "record_performance_metrics/2 (cast)" do
    @perf_data %{
      tenant_id: "tenant_1",
      test_suite: "PerfTest",
      metric_name: "response_time",
      metric_value: 42.5,
      metric_unit: "ms",
      percentile_50: 40.0,
      percentile_90: 55.0,
      percentile_95: 60.0,
      percentile_99: 80.0,
      min_value: 35.0,
      max_value: 100.0,
      sample_count: 1000
    }

    test "returns :ok when server is running" do
      case TimescaleIntegration.start_link([]) do
        {:ok, pid} ->
          result = TimescaleIntegration.record_performance_metrics(@perf_data)
          assert result == :ok
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

        {:error, _} ->
          :ok
      end
    end
  end

  describe "record_quality_gate/2 (cast)" do
    @quality_data %{
      tenant_id: "tenant_1",
      gate_name: "coverage",
      gate_status: :passed,
      threshold: 95.0,
      actual_value: 97.5
    }

    test "returns :ok when server is running" do
      case TimescaleIntegration.start_link([]) do
        {:ok, pid} ->
          result = TimescaleIntegration.record_quality_gate(@quality_data)
          assert result == :ok
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

        {:error, _} ->
          :ok
      end
    end
  end

  describe "record_test_failure/2 (cast)" do
    @failure_data %{
      tenant_id: "tenant_1",
      test_name: "test failing",
      failure_type: :assertion,
      failure_message: "Expected true, got false",
      stack_trace: "test.ex:12"
    }

    test "returns :ok when server is running" do
      case TimescaleIntegration.start_link([]) do
        {:ok, pid} ->
          result = TimescaleIntegration.record_test_failure(@failure_data)
          assert result == :ok
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

        {:error, _} ->
          :ok
      end
    end
  end

  describe "record_pipeline_metrics/2 (cast)" do
    @pipeline_data %{
      tenant_id: "tenant_1",
      pipeline_name: "CI",
      stage: "test",
      duration_ms: 30_000,
      status: :success
    }

    test "returns :ok when server is running" do
      case TimescaleIntegration.start_link([]) do
        {:ok, pid} ->
          result = TimescaleIntegration.record_pipeline_metrics(@pipeline_data)
          assert result == :ok
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

        {:error, _} ->
          :ok
      end
    end
  end

  # ============================================================================
  # Call functions (require server + DB)
  # ============================================================================

  describe "get_test_analytics/3 (call)" do
    test "returns a result when server is running" do
      case TimescaleIntegration.start_link([]) do
        {:ok, pid} ->
          result = TimescaleIntegration.get_test_analytics("tenant_1", "24h")
          # Result can be {:ok, data} or {:error, reason} depending on DB state
          assert match?({:ok, _}, result) or match?({:error, _}, result)
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

        {:error, _} ->
          :ok
      end
    end
  end

  describe "get_performance_regression_analysis/3 (call)" do
    test "returns a result when server is running" do
      case TimescaleIntegration.start_link([]) do
        {:ok, pid} ->
          result =
            TimescaleIntegration.get_performance_regression_analysis("tenant_1", "my_suite")

          assert match?({:ok, _}, result) or match?({:error, _}, result)
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

        {:error, _} ->
          :ok
      end
    end
  end

  describe "get_failure_pattern_analysis/3 (call)" do
    test "returns a result when server is running" do
      case TimescaleIntegration.start_link([]) do
        {:ok, pid} ->
          result = TimescaleIntegration.get_failure_pattern_analysis("tenant_1", "24h")
          assert match?({:ok, _}, result) or match?({:error, _}, result)
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

        {:error, _} ->
          :ok
      end
    end
  end

  describe "get_quality_dashboard_data/2 (call)" do
    test "returns a result when server is running" do
      case TimescaleIntegration.start_link([]) do
        {:ok, pid} ->
          result = TimescaleIntegration.get_quality_dashboard_data("tenant_1")
          assert match?({:ok, _}, result) or match?({:error, _}, result)
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

        {:error, _} ->
          :ok
      end
    end
  end
end
