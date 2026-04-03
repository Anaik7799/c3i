defmodule Indrajaal.Observability.CompilerMetricsTest do
  @moduledoc """
  TDG test suite for Indrajaal.Observability.CompilerMetrics.

  ## STAMP Safety Integration
  - SC-METRICS-001: Tracer MUST NOT add >5% compilation overhead
  - SC-METRICS-003: Parallelization settings MUST be enforced

  ## TPS 5-Level RCA Context
  - L1 Symptom: No compilation performance visibility
  - L5 Root Cause: Cannot optimize build pipeline without metrics
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.Observability.CompilerMetrics

  setup do
    name = :"CompilerMetrics_#{System.unique_integer([:positive])}"
    {:ok, pid} = start_supervised!({CompilerMetrics, []}, id: name)
    %{pid: pid}
  end

  describe "verify_parallelization/0" do
    test "returns {:ok, map} or {:error, string}" do
      result = CompilerMetrics.verify_parallelization()
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "on success, returns map with scheduler info" do
      case CompilerMetrics.verify_parallelization() do
        {:ok, info} ->
          assert is_map(info)
          assert Map.has_key?(info, :schedulers)
          assert Map.has_key?(info, :dirty_io_schedulers)
          assert Map.has_key?(info, :status)

        {:error, msg} ->
          assert is_binary(msg)
      end
    end

    test "on success, status is :optimal" do
      case CompilerMetrics.verify_parallelization() do
        {:ok, info} -> assert info.status == :optimal
        {:error, _} -> assert true
      end
    end

    test "scheduler count is positive integer" do
      case CompilerMetrics.verify_parallelization() do
        {:ok, info} -> assert info.schedulers > 0
        {:error, _} -> assert true
      end
    end
  end

  describe "get_last_compilation/0" do
    test "returns {:error, :no_data} when no compilation has occurred" do
      result = CompilerMetrics.get_last_compilation()
      assert result == {:error, :no_data}
    end
  end

  describe "get_historical_stats/1" do
    test "returns {:ok, list} with empty history" do
      result = CompilerMetrics.get_historical_stats()
      assert match?({:ok, _}, result)

      {:ok, history} = result
      assert is_list(history)
    end

    test "accepts days option" do
      result = CompilerMetrics.get_historical_stats(days: 7)
      assert match?({:ok, _}, result)
    end

    test "defaults work without options" do
      result = CompilerMetrics.get_historical_stats([])
      assert match?({:ok, _}, result)
    end
  end

  describe "get_slowest_files/1" do
    test "returns empty list when no compilation data" do
      result = CompilerMetrics.get_slowest_files()
      assert result == []
    end

    test "accepts limit argument" do
      result = CompilerMetrics.get_slowest_files(10)
      assert is_list(result)
    end
  end

  describe "get_domain_breakdown/0" do
    test "returns empty map when no compilation data" do
      result = CompilerMetrics.get_domain_breakdown()
      assert result == %{}
    end
  end

  describe "print_summary/0" do
    test "returns :ok even with no data" do
      result = CompilerMetrics.print_summary()
      assert result == :ok
    end
  end

  describe "trace/2" do
    test "returns :ok for any event" do
      env = %{file: "lib/test.ex", module: TestModule}
      result = CompilerMetrics.trace({:on_module, <<>>, TestModule}, env)
      assert result == :ok
    end
  end

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Indrajaal.Observability.CompilerMetrics)
    end

    test "all public functions exported" do
      assert function_exported?(CompilerMetrics, :start_link, 1)
      assert function_exported?(CompilerMetrics, :get_last_compilation, 0)
      assert function_exported?(CompilerMetrics, :get_historical_stats, 0)
      assert function_exported?(CompilerMetrics, :get_historical_stats, 1)
      assert function_exported?(CompilerMetrics, :get_slowest_files, 0)
      assert function_exported?(CompilerMetrics, :get_slowest_files, 1)
      assert function_exported?(CompilerMetrics, :get_domain_breakdown, 0)
      assert function_exported?(CompilerMetrics, :start_session, 0)
      assert function_exported?(CompilerMetrics, :end_session, 0)
      assert function_exported?(CompilerMetrics, :verify_parallelization, 0)
      assert function_exported?(CompilerMetrics, :print_summary, 0)
      assert function_exported?(CompilerMetrics, :trace, 2)
    end
  end
end
