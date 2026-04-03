defmodule Indrajaal.Metabolic.ResourceLifecycleIntegrationTest do
  @moduledoc """
  L4.4: Resource Lifecycle Management Integration Tests.

  Tests the resource management infrastructure:
  - Resource Pool allocation/deallocation
  - Resource Monitor metrics
  - Holon lifecycle states
  - BaseResource foundation
  - Resource capacity management

  STAMP Constraints:
  - SC-RES-001: Resource limits enforced
  - SC-RES-002: Resource deallocation required
  - SC-RES-003: Resource metrics tracked
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Performance.ResourcePool
  alias Indrajaal.Performance.ResourceMonitor
  alias Indrajaal.Core.Holon

  describe "L4.4: ResourcePool Module" do
    test "ResourcePool module is defined" do
      assert Code.ensure_loaded?(ResourcePool)
    end

    test "ResourcePool exports allocate_cpu/2" do
      assert function_exported?(ResourcePool, :allocate_cpu, 2)
    end

    test "ResourcePool exports allocate_memory/2" do
      assert function_exported?(ResourcePool, :allocate_memory, 2)
    end

    test "ResourcePool exports deallocate/2" do
      assert function_exported?(ResourcePool, :deallocate, 2)
    end

    test "ResourcePool exports get_pool_status/1" do
      assert function_exported?(ResourcePool, :get_pool_status, 1)
    end

    test "ResourcePool exports health_check/1" do
      assert function_exported?(ResourcePool, :health_check, 1)
    end
  end

  describe "L4.4: ResourcePool Operations" do
    setup do
      {:ok, pid} = ResourcePool.start_link(total_cpu: 16, total_memory: 32)

      on_exit(fn ->
        if Process.alive?(pid), do: GenServer.stop(pid, :normal, 100)
      end)

      {:ok, pool: pid}
    end

    test "allocate_cpu returns allocation ID", %{pool: pool} do
      result = ResourcePool.allocate_cpu(pool, cores: 2)

      assert {:ok, alloc_id} = result
      assert is_binary(alloc_id)
      assert String.starts_with?(alloc_id, "alloc_")
    end

    test "allocate_memory returns allocation ID", %{pool: pool} do
      result = ResourcePool.allocate_memory(pool, gb: 4)

      assert {:ok, alloc_id} = result
      assert is_binary(alloc_id)
    end

    test "get_pool_status returns resource availability", %{pool: pool} do
      status = ResourcePool.get_pool_status(pool)

      assert is_map(status)
      assert Map.has_key?(status, :available_cpu)
      assert Map.has_key?(status, :cpu)
    end

    test "deallocate frees resources", %{pool: pool} do
      {:ok, alloc_id} = ResourcePool.allocate_cpu(pool, cores: 4)
      initial_status = ResourcePool.get_pool_status(pool)
      initial_available = initial_status.available_cpu

      ResourcePool.deallocate(pool, alloc_id)

      new_status = ResourcePool.get_pool_status(pool)
      assert new_status.available_cpu == initial_available + 4
    end

    test "allocation fails when resources exhausted (SC-RES-001)", %{pool: pool} do
      # Try to allocate more than available
      result = ResourcePool.allocate_cpu(pool, cores: 1000)

      assert {:error, :insufficient_resources} = result
    end

    test "reset_pool clears all allocations", %{pool: pool} do
      ResourcePool.allocate_cpu(pool, cores: 4)
      ResourcePool.allocate_memory(pool, gb: 8)

      ResourcePool.reset_pool(pool)

      status = ResourcePool.get_pool_status(pool)
      assert status.available_cpu == 16
    end

    test "get_allocation_details returns allocation info", %{pool: pool} do
      {:ok, alloc_id} = ResourcePool.allocate_cpu(pool, cores: 2)

      {:ok, details} = ResourcePool.get_allocation_details(pool, alloc_id)

      assert details != nil
      assert details.allocated_amount == 2
      assert details.resource_type == :cpu
    end

    test "health_check returns healthy status", %{pool: pool} do
      {:ok, health} = ResourcePool.health_check(pool)

      assert health.status == :healthy
      assert Map.has_key?(health, :resource_utilization)
    end
  end

  describe "L4.4: ResourceMonitor Module" do
    test "ResourceMonitor module is defined" do
      assert Code.ensure_loaded?(ResourceMonitor)
    end

    test "ResourceMonitor exports get_status/1" do
      assert function_exported?(ResourceMonitor, :get_status, 1)
    end

    test "ResourceMonitor exports get_metrics/1" do
      assert function_exported?(ResourceMonitor, :get_metrics, 1)
    end
  end

  describe "L4.4: ResourceMonitor Operations" do
    setup do
      {:ok, pid} = ResourceMonitor.start_link([])

      on_exit(fn ->
        if Process.alive?(pid), do: GenServer.stop(pid, :normal, 100)
      end)

      {:ok, monitor: pid}
    end

    test "get_status returns system metrics", %{monitor: monitor} do
      {:ok, status} = ResourceMonitor.get_status(monitor)

      assert is_map(status)
      assert Map.has_key?(status, :cpu_usage)
      assert Map.has_key?(status, :memory_usage)
      assert Map.has_key?(status, :available)
    end

    test "get_metrics returns resource metrics (SC-RES-003)", %{monitor: monitor} do
      {:ok, metrics} = ResourceMonitor.get_metrics(monitor)

      assert is_map(metrics)
      assert Map.has_key?(metrics, :cpu)
      assert Map.has_key?(metrics, :resource_utilization)
    end

    test "perform_operation completes successfully", %{monitor: monitor} do
      result = ResourceMonitor.perform_operation(monitor, :test_op, [])

      assert {:ok, %{status: :ok}} = result
    end

    test "process_tenant_data stores tenant data", %{monitor: monitor} do
      data = %{tenant_id: "tenant_1", data: %{key: "value"}}

      result = ResourceMonitor.process_tenant_data(monitor, data)

      assert {:ok, :processed} = result

      {:ok, tenant_data} = ResourceMonitor.get_tenant_data(monitor, "tenant_1")
      assert tenant_data != nil
    end

    test "get_tenant_data_as enforces tenant isolation", %{monitor: monitor} do
      data = %{tenant_id: "tenant_a", data: %{secret: "value"}}
      ResourceMonitor.process_tenant_data(monitor, data)

      # Same tenant can access
      {:ok, _} = ResourceMonitor.get_tenant_data_as(monitor, "tenant_a", "tenant_a")

      # Different tenant cannot access
      {:error, :unauthorized} =
        ResourceMonitor.get_tenant_data_as(monitor, "tenant_a", "tenant_b")
    end

    test "execute_goal returns completion status", %{monitor: monitor} do
      goal = %{id: "goal_1", type: :optimization}

      {:ok, result} = ResourceMonitor.execute_goal(monitor, goal)

      assert result.status == :completed
      assert result.goal_achieved == true
    end

    test "apply_feedback adapts configuration", %{monitor: monitor} do
      feedback = %{id: "fb_1", type: :performance}

      {:ok, result} = ResourceMonitor.apply_feedback(monitor, feedback)

      assert result.adapted == true
      assert result.configuration_updated == true
    end
  end

  describe "L4.4: Holon Behaviour" do
    test "Holon behaviour module is defined" do
      assert Code.ensure_loaded?(Holon)
    end

    test "Holon provides __using__ macro" do
      # Holon is a behaviour that modules can use
      exports = Holon.__info__(:macros)
      assert {:__using__, 1} in exports
    end

    test "Holon exports layers/0 function" do
      assert function_exported?(Holon, :layers, 0)
    end

    test "Holon exports layer_depth/1 function" do
      assert function_exported?(Holon, :layer_depth, 1)
    end

    test "Holon exports parent_layer?/2 function" do
      assert function_exported?(Holon, :parent_layer?, 2)
    end
  end

  describe "L4.4: Holon Layer Hierarchy" do
    test "layers returns 7 fractal layers" do
      layers = Holon.layers()

      assert is_list(layers)
      assert length(layers) == 7
      assert :function in layers
      assert :module in layers
      assert :agent in layers
      assert :container in layers
      assert :node in layers
      assert :cluster in layers
      assert :federation in layers
    end

    test "layer_depth returns correct depth" do
      assert Holon.layer_depth(:function) == 0
      assert Holon.layer_depth(:module) == 1
      assert Holon.layer_depth(:agent) == 2
      assert Holon.layer_depth(:container) == 3
      assert Holon.layer_depth(:node) == 4
      assert Holon.layer_depth(:cluster) == 5
      assert Holon.layer_depth(:federation) == 6
    end

    test "parent_layer? correctly identifies parent layers" do
      # Federation is parent of cluster
      assert Holon.parent_layer?(:federation, :cluster) == true

      # Cluster is parent of node
      assert Holon.parent_layer?(:cluster, :node) == true

      # Function is not parent of container
      assert Holon.parent_layer?(:function, :container) == false
    end
  end

  describe "L4.4: BaseResource Foundation" do
    test "BaseResource module is defined" do
      assert Code.ensure_loaded?(Indrajaal.BaseResource)
    end

    test "BaseResource provides __using__ macro" do
      exports = Indrajaal.BaseResource.__info__(:macros)
      assert {:__using__, 1} in exports
    end
  end

  describe "L4.4: Resource Capacity Management" do
    setup do
      {:ok, pool} = ResourcePool.start_link(total_cpu: 8, total_memory: 16)

      on_exit(fn ->
        if Process.alive?(pool), do: GenServer.stop(pool, :normal, 100)
      end)

      {:ok, pool: pool}
    end

    test "multiple allocations track correctly", %{pool: pool} do
      {:ok, _} = ResourcePool.allocate_cpu(pool, cores: 2)
      {:ok, _} = ResourcePool.allocate_cpu(pool, cores: 2)

      status = ResourcePool.get_pool_status(pool)
      assert status.available_cpu == 4
    end

    test "mixed resource allocations work", %{pool: pool} do
      {:ok, cpu_id} = ResourcePool.allocate_cpu(pool, cores: 2)
      {:ok, _mem_id} = ResourcePool.allocate_memory(pool, gb: 4)

      status = ResourcePool.get_pool_status(pool)
      assert status.available_cpu == 6

      ResourcePool.deallocate(pool, cpu_id)
      status = ResourcePool.get_pool_status(pool)
      assert status.available_cpu == 8
    end

    test "allocation IDs are unique", %{pool: pool} do
      {:ok, id1} = ResourcePool.allocate_cpu(pool, cores: 1)
      {:ok, id2} = ResourcePool.allocate_cpu(pool, cores: 1)
      {:ok, id3} = ResourcePool.allocate_memory(pool, gb: 1)

      ids = [id1, id2, id3]
      assert length(Enum.uniq(ids)) == 3
    end
  end

  describe "L4.4: Resource Telemetry" do
    setup do
      {:ok, pool} = ResourcePool.start_link(total_cpu: 16, total_memory: 32)

      on_exit(fn ->
        if Process.alive?(pool), do: GenServer.stop(pool, :normal, 100)
      end)

      {:ok, pool: pool}
    end

    test "allocation emits telemetry event", %{pool: pool} do
      test_pid = self()

      handler = fn event, measurements, metadata, _config ->
        send(test_pid, {:telemetry, event, measurements, metadata})
      end

      :telemetry.attach(
        "test_resource_pool_alloc",
        [:resource_pool, :allocation],
        handler,
        nil
      )

      ResourcePool.allocate_cpu(pool, cores: 2)

      assert_receive {:telemetry, [:resource_pool, :allocation], %{amount: 2}, %{type: :cpu}},
                     1000

      :telemetry.detach("test_resource_pool_alloc")
    end
  end
end
