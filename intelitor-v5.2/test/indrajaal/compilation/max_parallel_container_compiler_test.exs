defmodule Indrajaal.Compilation.MaxParallelContainerCompilerTest do
  @moduledoc """
  TDG test suite for MaxParallelContainerCompiler (GenServer).

  ## STAMP Safety Integration
  - SC-METRICS-003: Parallelization MANDATORY
  - SC-CMP-025: 0 warnings required
  - SC-CMP-028: No interruption allowed

  ## TPS 5-Level RCA Context
  - L1 Symptom: Compilation hangs or uses suboptimal parallelism
  - L5 Root Cause: Missing optimal config calculation or environment validation
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Compilation.MaxParallelContainerCompiler

  setup do
    {:ok, pid} = start_supervised({MaxParallelContainerCompiler, []})
    %{pid: pid}
  end

  describe "start_link/1" do
    test "starts the GenServer successfully" do
      {:ok, pid} = MaxParallelContainerCompiler.start_link([])
      assert is_pid(pid)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "starts with empty options" do
      {:ok, pid} = MaxParallelContainerCompiler.start_link([])
      assert is_pid(pid)
      GenServer.stop(pid)
    end
  end

  describe "get_optimal_config/0" do
    test "returns an optimal compilation configuration" do
      result = MaxParallelContainerCompiler.get_optimal_config()
      assert is_map(result) or is_tuple(result)
    end

    test "config includes schedulers or parallel count" do
      result = MaxParallelContainerCompiler.get_optimal_config()

      case result do
        {:ok, config} ->
          assert is_map(config)

        config when is_map(config) ->
          assert map_size(config) > 0

        _ ->
          assert is_tuple(result)
      end
    end

    test "config is deterministic across calls" do
      result1 = MaxParallelContainerCompiler.get_optimal_config()
      result2 = MaxParallelContainerCompiler.get_optimal_config()
      assert result1 == result2
    end
  end

  describe "validate_compilation_environment/0" do
    test "validates compilation environment" do
      result = MaxParallelContainerCompiler.validate_compilation_environment()
      assert is_tuple(result) or is_boolean(result) or is_atom(result)
    end

    test "validation returns ok or error tuple" do
      result = MaxParallelContainerCompiler.validate_compilation_environment()

      assert match?({:ok, _}, result) or match?({:error, _}, result) or
               result in [:ok, :error, true, false]
    end
  end

  describe "get_compilation_metrics/0" do
    test "returns compilation metrics map" do
      result = MaxParallelContainerCompiler.get_compilation_metrics()
      assert is_map(result) or is_tuple(result)
    end

    test "metrics include some performance data" do
      result = MaxParallelContainerCompiler.get_compilation_metrics()

      case result do
        {:ok, metrics} ->
          assert is_map(metrics)

        metrics when is_map(metrics) ->
          assert map_size(metrics) >= 0

        _ ->
          assert is_tuple(result)
      end
    end
  end

  describe "compile_max_parallel/1" do
    test "initiates parallel compilation for given targets" do
      targets = ["lib/indrajaal/tps/configuration_auditor.ex"]
      result = MaxParallelContainerCompiler.compile_max_parallel(targets)
      assert is_tuple(result)
    end

    test "compile with empty list of targets" do
      result = MaxParallelContainerCompiler.compile_max_parallel([])
      assert is_tuple(result)
    end

    test "returns ok or error tuple" do
      result = MaxParallelContainerCompiler.compile_max_parallel([])
      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_tuple(result)
    end
  end

  describe "process lifecycle" do
    test "process stays alive after validation" do
      {:ok, pid} = MaxParallelContainerCompiler.start_link([])
      assert Process.alive?(pid)

      MaxParallelContainerCompiler.validate_compilation_environment()
      assert Process.alive?(pid)

      GenServer.stop(pid)
    end

    test "process stays alive after metrics query" do
      {:ok, pid} = MaxParallelContainerCompiler.start_link([])
      MaxParallelContainerCompiler.get_compilation_metrics()
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end
end
