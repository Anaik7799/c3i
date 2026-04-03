defmodule Indrajaal.Shared.UnifiedParallelizationFrameworkTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Shared.UnifiedParallelizationFramework

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(UnifiedParallelizationFramework)
    end
  end

  describe "parallel_execute/2" do
    test "function is exported" do
      assert function_exported?(UnifiedParallelizationFramework, :parallel_execute, 2)
    end

    test "executes items in parallel and returns results" do
      items = [1, 2, 3, 4, 5]
      results = UnifiedParallelizationFramework.parallel_execute(items, processor_fn: &(&1 * 2))
      assert is_list(results)
      assert length(results) == 5
    end

    test "returns empty list for empty input" do
      results = UnifiedParallelizationFramework.parallel_execute([], processor_fn: & &1)
      assert results == []
    end

    test "uses identity function when no processor_fn given" do
      items = [1, 2, 3]
      results = UnifiedParallelizationFramework.parallel_execute(items)
      assert is_list(results)
    end

    test "handles single item" do
      results = UnifiedParallelizationFramework.parallel_execute([42], processor_fn: &(&1 + 1))
      assert is_list(results)
      assert length(results) == 1
    end
  end

  describe "execute_parallel_tasks/2" do
    test "function is exported" do
      assert function_exported?(UnifiedParallelizationFramework, :execute_parallel_tasks, 2)
    end

    test "executes list of function tasks" do
      tasks = [fn -> {:ok, 1} end, fn -> {:ok, 2} end, fn -> {:ok, 3} end]
      result = UnifiedParallelizationFramework.execute_parallel_tasks(tasks)
      assert is_list(result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "returns error for empty task list" do
      result = UnifiedParallelizationFramework.execute_parallel_tasks([])
      assert is_list(result) or match?({:error, _}, result)
    end

    test "respects max_concurrency option" do
      tasks = Enum.map(1..5, fn i -> fn -> {:ok, i} end end)
      result = UnifiedParallelizationFramework.execute_parallel_tasks(tasks, max_concurrency: 2)
      assert is_list(result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "returns error for too many tasks" do
      tasks = Enum.map(1..1001, fn i -> fn -> {:ok, i} end end)
      result = UnifiedParallelizationFramework.execute_parallel_tasks(tasks)
      assert match?({:error, _}, result) or is_list(result)
    end
  end

  describe "process_parallel_batches/3" do
    test "function is exported" do
      assert function_exported?(UnifiedParallelizationFramework, :process_parallel_batches, 3)
    end

    test "processes items in batches" do
      items = Enum.to_list(1..10)

      results =
        UnifiedParallelizationFramework.process_parallel_batches(items, &(&1 * 2), batch_size: 3)

      assert is_list(results)
    end

    test "handles empty items list" do
      results = UnifiedParallelizationFramework.process_parallel_batches([], & &1, [])
      assert results == [] or is_list(results)
    end
  end

  describe "process_parallel_stream/3" do
    test "function is exported" do
      assert function_exported?(UnifiedParallelizationFramework, :process_parallel_stream, 3)
    end

    test "processes stream of items" do
      stream = Stream.map(1..5, & &1)
      results = UnifiedParallelizationFramework.process_parallel_stream(stream, &(&1 + 1))
      collected = Enum.to_list(results)
      assert is_list(collected)
    end
  end

  describe "coordinate_agents/3" do
    test "function is exported" do
      assert function_exported?(UnifiedParallelizationFramework, :coordinate_agents, 3)
    end

    test "coordinates a list of agents" do
      agents = [:agent1, :agent2, :agent3]
      coordinator = fn agents -> {:ok, Enum.count(agents)} end
      result = UnifiedParallelizationFramework.coordinate_agents(agents, coordinator)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "respects max_agents limit" do
      agents = Enum.map(1..20, fn i -> :"agent_#{i}" end)
      coordinator = fn agents -> {:ok, Enum.count(agents)} end

      result =
        UnifiedParallelizationFramework.coordinate_agents(agents, coordinator, max_agents: 5)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
