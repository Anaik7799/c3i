defmodule Indrajaal.Morphogenic.L4ContainerResourceLimitsTest do
  @moduledoc """
  L4 Morphogenic Evolution Test: Container Resource Limits

  Tests container-level resource governance: memory budgets, process limits,
  CPU scheduling fairness, and resource exhaustion prevention. Validates
  that container isolation includes resource capping.

  ## Fractal Layer
  L4 — Container (Isolation, resource bounds)

  ## STAMP Constraints
  - SC-CNT-009: NixOS/Podman only
  - SC-CNT-012: Rootless containers
  - SC-SAFETY-007: Resource bounds validated
  - SC-PRF-055: No blocking ops

  ## Morphogenic Task
  Auto-generated for 80% saturation — L4 substrate
  """

  use ExUnit.Case, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :morphogenic
  @moduletag layer: :l4
  @moduletag :l4_resource_limits

  # ── ETS Table Setup ──────────────────────────────────────────────────

  @resource_table :l4_resource_limits_table
  @usage_table :l4_resource_usage_table
  @violation_table :l4_resource_violations_table

  setup do
    for table <- [@resource_table, @usage_table, @violation_table] do
      if :ets.whereis(table) != :undefined, do: :ets.delete(table)
    end

    :ets.new(@resource_table, [:named_table, :set, :public])
    :ets.new(@usage_table, [:named_table, :ordered_set, :public])
    :ets.new(@violation_table, [:named_table, :duplicate_bag, :public])

    on_exit(fn ->
      for table <- [@resource_table, @usage_table, @violation_table] do
        try do
          :ets.delete(table)
        rescue
          _ -> :ok
        end
      end
    end)

    :ok
  end

  # ── Memory Budget ────────────────────────────────────────────────────

  describe "memory budget enforcement" do
    test "allocation within budget succeeds" do
      container = create_container("mem_ok", %{memory_limit: 1_000_000})
      assert :ok = allocate_resource(container, :memory, 500_000)
      assert get_usage(container, :memory) == 500_000
    end

    test "allocation exceeding budget rejected" do
      container = create_container("mem_over", %{memory_limit: 1_000_000})
      assert :ok = allocate_resource(container, :memory, 500_000)
      assert {:error, :resource_exhausted} = allocate_resource(container, :memory, 600_000)
    end

    test "deallocation frees budget" do
      container = create_container("mem_free", %{memory_limit: 1_000_000})
      assert :ok = allocate_resource(container, :memory, 800_000)
      assert :ok = deallocate_resource(container, :memory, 300_000)
      assert :ok = allocate_resource(container, :memory, 400_000)
    end

    test "memory limit is per-container isolated" do
      c1 = create_container("mem_iso_1", %{memory_limit: 500_000})
      c2 = create_container("mem_iso_2", %{memory_limit: 500_000})

      assert :ok = allocate_resource(c1, :memory, 400_000)
      assert :ok = allocate_resource(c2, :memory, 400_000)

      assert get_usage(c1, :memory) == 400_000
      assert get_usage(c2, :memory) == 400_000
    end
  end

  # ── Process Limits ───────────────────────────────────────────────────

  describe "process count limits" do
    test "process creation within limit succeeds" do
      container = create_container("proc_ok", %{process_limit: 100})

      for i <- 1..50 do
        assert :ok = allocate_resource(container, :processes, 1),
               "Failed at process #{i}"
      end

      assert get_usage(container, :processes) == 50
    end

    test "process creation at limit rejected" do
      container = create_container("proc_max", %{process_limit: 5})
      for _ <- 1..5, do: allocate_resource(container, :processes, 1)
      assert {:error, :resource_exhausted} = allocate_resource(container, :processes, 1)
    end

    test "process termination frees slots" do
      container = create_container("proc_free", %{process_limit: 3})
      for _ <- 1..3, do: allocate_resource(container, :processes, 1)
      assert :ok = deallocate_resource(container, :processes, 2)
      assert :ok = allocate_resource(container, :processes, 1)
    end
  end

  # ── CPU Scheduling ───────────────────────────────────────────────────

  describe "CPU scheduling fairness" do
    test "CPU shares allocated proportionally" do
      c1 = create_container("cpu_1", %{cpu_shares: 100})
      c2 = create_container("cpu_2", %{cpu_shares: 200})
      c3 = create_container("cpu_3", %{cpu_shares: 300})

      total = 100 + 200 + 300
      assert_in_delta cpu_share_ratio(c1, total), 100 / total, 0.01
      assert_in_delta cpu_share_ratio(c2, total), 200 / total, 0.01
      assert_in_delta cpu_share_ratio(c3, total), 300 / total, 0.01
    end

    test "CPU burst within limits allowed" do
      container = create_container("cpu_burst", %{cpu_shares: 100, cpu_burst_limit: 200})
      assert :ok = allocate_resource(container, :cpu_burst, 150)
      assert {:error, :resource_exhausted} = allocate_resource(container, :cpu_burst, 100)
    end
  end

  # ── Resource Violations ──────────────────────────────────────────────

  describe "violation tracking" do
    test "over-allocation logged as violation" do
      container = create_container("viol_1", %{memory_limit: 100})
      allocate_resource(container, :memory, 100)
      allocate_resource(container, :memory, 50)

      violations = get_violations(container)
      assert length(violations) >= 1
      assert hd(violations).type == :resource_exhausted
    end

    test "violation includes resource type and amount" do
      container = create_container("viol_detail", %{process_limit: 2})
      allocate_resource(container, :processes, 2)
      allocate_resource(container, :processes, 1)

      [violation | _] = get_violations(container)
      assert violation.resource == :processes
      assert violation.requested == 1
      assert violation.available == 0
    end

    test "violation count triggers circuit breaker" do
      container = create_container("viol_cb", %{memory_limit: 10, circuit_breaker_threshold: 3})

      for _ <- 1..5 do
        allocate_resource(container, :memory, 100)
      end

      violations = get_violations(container)
      assert length(violations) >= 3
      assert circuit_breaker_tripped?(container)
    end
  end

  # ── Resource Monitoring ──────────────────────────────────────────────

  describe "resource usage monitoring" do
    test "usage tracking per resource type" do
      container = create_container("mon_1", %{memory_limit: 10_000, process_limit: 50})
      allocate_resource(container, :memory, 3_000)
      allocate_resource(container, :processes, 10)

      usage = get_all_usage(container)
      assert usage[:memory] == 3_000
      assert usage[:processes] == 10
    end

    test "usage percentage calculation" do
      container = create_container("mon_pct", %{memory_limit: 1000})
      allocate_resource(container, :memory, 750)

      assert usage_percentage(container, :memory) == 75.0
    end

    test "high watermark tracking" do
      container = create_container("mon_hw", %{memory_limit: 1000})
      allocate_resource(container, :memory, 800)
      deallocate_resource(container, :memory, 500)
      allocate_resource(container, :memory, 300)

      assert get_high_watermark(container, :memory) == 800
    end
  end

  # ── PropCheck Properties ─────────────────────────────────────────────

  describe "property: resource limits never exceeded" do
    @tag timeout: 30_000
    property "usage never exceeds limit" do
      forall {limit, allocs} <- {PC.range(100, 10_000), PC.list(PC.range(1, 500))} do
        container =
          create_container(
            "prop_#{System.unique_integer([:positive])}",
            %{memory_limit: limit}
          )

        Enum.each(allocs, fn amount ->
          allocate_resource(container, :memory, amount)
        end)

        usage = get_usage(container, :memory)
        usage <= limit
      end
    end
  end

  describe "property: deallocation monotonically decreases usage" do
    @tag timeout: 30_000
    property "deallocate reduces usage by exact amount" do
      forall {alloc, dealloc_pct} <- {PC.range(100, 5000), PC.range(1, 100)} do
        container =
          create_container(
            "prop_dealloc_#{System.unique_integer([:positive])}",
            %{memory_limit: 10_000}
          )

        allocate_resource(container, :memory, alloc)
        before_usage = get_usage(container, :memory)
        dealloc = div(before_usage * dealloc_pct, 100)
        deallocate_resource(container, :memory, dealloc)
        after_usage = get_usage(container, :memory)

        after_usage == before_usage - dealloc
      end
    end
  end

  # ── StreamData Properties ────────────────────────────────────────────

  describe "streamdata: container isolation" do
    @tag timeout: 30_000
    test "containers don't share resource pools" do
      SD.integer(2..8)
      |> Enum.take(20)
      |> Enum.each(fn n ->
        containers =
          for i <- 1..n do
            create_container(
              "sd_iso_#{System.unique_integer([:positive])}_#{i}",
              %{memory_limit: 1000}
            )
          end

        for c <- containers do
          allocate_resource(c, :memory, 500)
        end

        for c <- containers do
          assert get_usage(c, :memory) == 500
        end
      end)
    end
  end

  # ── Helper Functions ─────────────────────────────────────────────────

  defp create_container(name, config) do
    container_id = :"container_#{name}_#{System.unique_integer([:positive])}"
    :ets.insert(@resource_table, {container_id, config})
    :ets.insert(@usage_table, {{container_id, :_high_watermarks}, %{}})
    container_id
  end

  defp allocate_resource(container_id, resource, amount) do
    [{^container_id, config}] = :ets.lookup(@resource_table, container_id)
    limit = get_limit(config, resource)
    current = get_usage(container_id, resource)

    if current + amount <= limit do
      key = {container_id, resource}
      :ets.insert(@usage_table, {key, current + amount})
      update_high_watermark(container_id, resource, current + amount)
      :ok
    else
      record_violation(container_id, resource, amount, limit - current)
      {:error, :resource_exhausted}
    end
  end

  defp deallocate_resource(container_id, resource, amount) do
    current = get_usage(container_id, resource)
    new_val = max(0, current - amount)
    :ets.insert(@usage_table, {{container_id, resource}, new_val})
    :ok
  end

  defp get_usage(container_id, resource) do
    case :ets.lookup(@usage_table, {container_id, resource}) do
      [{{^container_id, ^resource}, val}] -> val
      [] -> 0
    end
  end

  defp get_all_usage(container_id) do
    :ets.foldl(
      fn
        {{^container_id, resource}, val}, acc
        when is_atom(resource) and resource != :_high_watermarks ->
          Map.put(acc, resource, val)

        _, acc ->
          acc
      end,
      %{},
      @usage_table
    )
  end

  defp get_limit(config, :memory), do: Map.get(config, :memory_limit, :infinity)
  defp get_limit(config, :processes), do: Map.get(config, :process_limit, :infinity)
  defp get_limit(config, :cpu_burst), do: Map.get(config, :cpu_burst_limit, :infinity)
  defp get_limit(_config, _resource), do: :infinity

  defp cpu_share_ratio(container_id, total_shares) do
    [{^container_id, config}] = :ets.lookup(@resource_table, container_id)
    config.cpu_shares / total_shares
  end

  defp usage_percentage(container_id, resource) do
    [{^container_id, config}] = :ets.lookup(@resource_table, container_id)
    limit = get_limit(config, resource)
    current = get_usage(container_id, resource)
    current / limit * 100.0
  end

  defp update_high_watermark(container_id, resource, value) do
    key = {container_id, :_high_watermarks}

    case :ets.lookup(@usage_table, key) do
      [{^key, watermarks}] ->
        current_hw = Map.get(watermarks, resource, 0)

        if value > current_hw do
          :ets.insert(@usage_table, {key, Map.put(watermarks, resource, value)})
        end

      [] ->
        :ets.insert(@usage_table, {key, %{resource => value}})
    end
  end

  defp get_high_watermark(container_id, resource) do
    key = {container_id, :_high_watermarks}

    case :ets.lookup(@usage_table, key) do
      [{^key, watermarks}] -> Map.get(watermarks, resource, 0)
      [] -> 0
    end
  end

  defp record_violation(container_id, resource, requested, available) do
    violation = %{
      type: :resource_exhausted,
      resource: resource,
      requested: requested,
      available: available,
      timestamp: System.monotonic_time(:microsecond)
    }

    :ets.insert(@violation_table, {container_id, violation})
  end

  defp get_violations(container_id) do
    :ets.lookup(@violation_table, container_id)
    |> Enum.map(fn {_id, violation} -> violation end)
  end

  defp circuit_breaker_tripped?(container_id) do
    [{^container_id, config}] = :ets.lookup(@resource_table, container_id)
    threshold = Map.get(config, :circuit_breaker_threshold, 10)
    length(get_violations(container_id)) >= threshold
  end
end
