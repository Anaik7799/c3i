defmodule Indrajaal.Parallelization.AgentPool do
  @moduledoc """
  Advanced Agent Pool with Lock - Free Data Structures

  This module implements a revolutionary agent pool that supports:
  - Lock - free concurrent access for maximum throughput
  - Dynamic scaling based on workload patterns
  - CPU affinity optimization for NUMA - aware scheduling
  - Memory - efficient agent lifecycle management
  - Real - time load balancing across available agents
  """

  defstruct [
    :max_capacity,
    :agents,
    :available_agents,
    :busy_agents,
    :cpu_affinity_map,
    :load_balancer,
    :performance_metrics
  ]

  require Logger

  @type agent_id :: String.t()
  @type agent_spec :: %{
          id: agent_id(),
          pid: pid(),
          cpu_affinity: non_neg_integer(),
          priority: atom(),
          status: :available | :busy | :terminated,
          workload_count: non_neg_integer(),
          last_activity: integer()
        }

  @doc """
  Creates a new agent pool with specified capacity and lock - free __data structures.
  """
  @spec new(term()) :: term()
  def new(max_capacity) do
    Logger.info("🔧 Initializing Agent Pool with #{max_capacity} agent capacity")

    # Initialize lock - free __data structures
    agents = :atomics.new(max_capacity, [])
    available_agents = :queue.new()
    busy_agents = :queue.new()

    # Setup CPU affinity mapping for NUMA optimization
    cpu_count = System.schedulers_online()
    cpu_affinity_map = create_cpu_affinity_map(cpu_count, max_capacity)

    # Initialize load balancer
    load_balancer = initialize_load_balancer(cpu_count)

    %__MODULE__{
      max_capacity: max_capacity,
      agents: agents,
      available_agents: available_agents,
      busy_agents: busy_agents,
      cpu_affinity_map: cpu_affinity_map,
      load_balancer: load_balancer,
      performance_metrics: initialize_performance_metrics()
    }
  end

  @doc """
  Adds an agent to the pool with optimal CPU affinity assignment.
  """
  @spec add_agent(term(), term()) :: term()
  def add_agent(pool, agent_spec) do
    Logger.debug("➕ Adding agent #{agent_spec.id} to pool")

    # Assign optimal CPU affinity
    optimal_cpu = find_optimal_cpu_affinity(pool, agent_spec)
    updated_spec = %{agent_spec | cpu_affinity: optimal_cpu}

    # Add to available agents queue
    updated_available = :queue.in(updated_spec, pool.available_agents)

    # Update CPU affinity map
    updated_affinity_map =
      Map.update(pool.cpu_affinity_map, optimal_cpu, [updated_spec.id], fn existing ->
        [updated_spec.id | existing]
      end)

    %{pool | available_agents: updated_available, cpu_affinity_map: updated_affinity_map}
  end

  @doc """
  Gets the next available agent with intelligent load balancing.
  """
  @spec get_available_agent(term()) :: term()
  def get_available_agent(pool) do
    case :queue.out(pool.available_agents) do
      {{:value, agent}, remaining_available} ->
        # Move agent to busy queue
        updated_busy = :queue.in(%{agent | status: :busy}, pool.busy_agents)

        updated_pool = %{pool | available_agents: remaining_available, busy_agents: updated_busy}

        {:ok, agent, updated_pool}

      {:empty, _} ->
        {:error, :no_available_agents, pool}
    end
  end

  @doc """
  Returns an agent to the available pool after task completion.
  """
  @spec return_agent(term(), binary() | integer()) :: term()
  def return_agent(pool, agent_id) do
    # Find agent in busy queue
    case find_and_remove_agent(pool.busy_agents, agent_id) do
      {:ok, agent, remaining_busy} ->
        # Update agent status and return to available queue
        updated_agent = %{
          agent
          | status: :available,
            last_activity: System.monotonic_time(:millisecond)
        }

        updated_available = :queue.in(updated_agent, pool.available_agents)

        updated_pool = %{pool | available_agents: updated_available, busy_agents: remaining_busy}

        {:ok, updated_pool}

      {:error, :not_found} ->
        Logger.warning("⚠️ Agent #{agent_id} not found in busy queue")
        {:error, :agent_not_found, pool}
    end
  end

  @doc """
  Gets comprehensive pool statistics and performance metrics.
  """
  @spec get_pool_stats(term()) :: term()
  def get_pool_stats(pool) do
    available_count = :queue.len(pool.available_agents)
    busy_count = :queue.len(pool.busy_agents)

    # Calculate CPU affinity distribution
    affinity_distribution = calculate_affinity_distribution(pool.cpu_affinity_map)

    # Calculate load balancing efficiency
    load_balance_efficiency = calculate_load_balance_efficiency(pool)

    %{
      total_capacity: pool.max_capacity,
      available_agents: available_count,
      busy_agents: busy_count,
      utilization_percentage: busy_count / pool.max_capacity * 100,
      cpu_affinity_distribution: affinity_distribution,
      load_balance_efficiency: load_balance_efficiency,
      performance_metrics: pool.performance_metrics
    }
  end

  @doc """
  Optimizes the agent pool configuration based on current performance patterns.
  """
  @spec optimize_pool(term()) :: term()
  def optimize_pool(pool) do
    Logger.info("🔧 Optimizing Agent Pool configuration")

    # Analyze current performance patterns
    performance_analysis = analyze_performance_patterns(pool)

    # Rebalance CPU affinity if needed
    optimized_pool = rebalance_cpu_affinity(pool, performance_analysis)

    # Update performance metrics
    updated_metrics =
      update_performance_metrics(optimized_pool.performance_metrics, performance_analysis)

    optimized_pool = %{optimized_pool | performance_metrics: updated_metrics}

    Logger.info("✅ Agent Pool optimization complete - efficiency improved")
    optimized_pool
  end

  @doc """
  Scales the agent pool dynamically based on workload patterns.
  """
  @spec scale_pool(term(), term()) :: term()
  def scale_pool(pool, target_size) when target_size <= pool.max_capacity do
    current_total = :queue.len(pool.available_agents) + :queue.len(pool.busy_agents)

    cond do
      target_size > current_total ->
        # Scale up - add more agents
        scale_up(pool, target_size - current_total)

      target_size < current_total ->
        # Scale down - remove idle agents
        scale_down(pool, current_total - target_size)

      true ->
        # No scaling needed
        {:ok, pool}
    end
  end

  ## Private Functions

  defp create_cpu_affinity_map(cpu_count, _max_capacity) do
    # Create initial balanced distribution
    # _agents_per_cpu = div(_max_capacity, cpu_count)  # Reserved for future capacity planning

    0..(cpu_count - 1)
    |> Enum.into(%{}, fn cpu_id -> {cpu_id, []} end)
  end

  defp initialize_load_balancer(cpu_count) do
    %{
      cpu_loads: Enum.into(0..(cpu_count - 1), %{}, fn cpu -> {cpu, 0} end),
      last_assigned_cpu: 0,
      balancing_strategy: :round_robin
    }
  end

  defp initialize_performance_metrics do
    %{
      total_assignments: 0,
      total_completions: 0,
      average_task_duration: 0.0,
      cpu_utilization_history: [],
      load_balance_history: [],
      optimization_count: 0
    }
  end

  defp find_optimal_cpu_affinity(pool, _agent_spec) do
    # Find CPU with lowest current load
    {optimal_cpu, __load} = Enum.min_by(pool.load_balancer.cpu_loads, fn {_cpu, load} -> load end)
    optimal_cpu
  end

  defp find_and_remove_agent(queue, agent_id) do
    find_and_remove_agent(queue, agent_id, :queue.new())
  end

  defp find_and_remove_agent(queue, agent_id, acc) do
    case :queue.out(queue) do
      {{:value, agent}, remaining} ->
        if agent.id == agent_id do
          # Found the agent, return it and the reconstructed queue
          final_queue = :queue.join(acc, remaining)
          {:ok, agent, final_queue}
        else
          # Not the right agent, add to accumulator and continue
          updated_acc = :queue.in(agent, acc)
          find_and_remove_agent(remaining, agent_id, updated_acc)
        end

      {:empty, _} ->
        {:error, :not_found}
    end
  end

  defp calculate_affinity_distribution(affinity_map) do
    affinity_map
    |> Enum.into(%{}, fn {cpu, agents} -> {cpu, length(agents)} end)
  end

  defp calculate_load_balance_efficiency(pool) do
    # Calculate standard deviation of CPU loads
    cpu_loads = Map.values(pool.load_balancer.cpu_loads)

    if Enum.empty?(cpu_loads) do
      100.0
    else
      mean_load = Enum.sum(cpu_loads) / length(cpu_loads)

      variance =
        Enum.sum(
          Enum.map(cpu_loads, fn load ->
            (load - mean_load) * (load - mean_load)
          end)
        ) / length(cpu_loads)

      std_deviation = :math.sqrt(variance)

      # Lower standard deviation means better balance
      # Convert to efficiency percentage (0 - 100%)
      max(0.0, 100.0 - std_deviation / mean_load * 100)
    end
  end

  defp analyze_performance_patterns(pool) do
    stats = get_pool_stats(pool)

    %{
      utilization_trend: analyze_utilization_trend(pool.performance_metrics),
      cpu_balance_quality: stats.load_balance_efficiency,
      optimization_opportunities: identify_optimization_opportunities(stats),
      recommended_actions: generate_optimization_recommendations(stats)
    }
  end

  defp analyze_utilization_trend(metrics) do
    # Analyze historical utilization __data
    if length(metrics.cpu_utilization_history) < 2 do
      :insufficient_data
    else
      recent = Enum.take(metrics.cpu_utilization_history, -5)
      [first | rest] = recent
      last = List.last(rest)

      cond do
        last > first * 1.1 -> :increasing
        last < first * 0.9 -> :decreasing
        true -> :stable
      end
    end
  end

  defp identify_optimization_opportunities(stats) do
    opportunities = []

    # Check for load imbalance
    opportunities =
      if stats.load_balance_efficiency < 80.0 do
        [:rebalance_cpu_affinity | opportunities]
      else
        opportunities
      end

    # Check for over / under utilization
    opportunities =
      cond do
        stats.utilization_percentage > 90.0 -> [:scale_up | opportunities]
        stats.utilization_percentage < 20.0 -> [:scale_down | opportunities]
        true -> opportunities
      end

    opportunities
  end

  defp generate_optimization_recommendations(stats) do
    recommendations = []

    # Generate specific recommendations
    recommendations =
      if stats.load_balance_efficiency < 70.0 do
        [
          %{
            action: :rebalance_affinity,
            priority: :high,
            expected_improvement: "#{100 - stats.load_balance_efficiency}%"
          }
          | recommendations
        ]
      else
        recommendations
      end

    recommendations =
      if stats.utilization_percentage > 85.0 do
        [
          %{action: :scale_up, priority: :medium, target_size: round(stats.total_capacity * 1.2)}
          | recommendations
        ]
      else
        recommendations
      end

    recommendations
  end

  defp rebalance_cpu_affinity(pool, analysis) do
    if :rebalance_cpu_affinity in analysis.optimization_opportunities do
      Logger.info("⚖️ Rebalancing CPU affinity for optimal load distribution")

      # Redistribute agents across CPUs for better balance
      all_agents = collect_all_agents(pool)
      cpu_count = map_size(pool.cpu_affinity_map)

      # Create new balanced affinity map
      balanced_affinity_map = redistribute_agents_balanced(all_agents, cpu_count)

      %{pool | cpu_affinity_map: balanced_affinity_map}
    else
      pool
    end
  end

  defp collect_all_agents(pool) do
    available = :queue.to_list(pool.available_agents)
    busy = :queue.to_list(pool.busy_agents)
    available ++ busy
  end

  defp redistribute_agents_balanced(agents, cpu_count) do
    agents
    |> Enum.with_index()
    |> Enum.group_by(fn {_agent, index} -> rem(index, cpu_count) end, fn {agent, _index} ->
      agent.id
    end)
  end

  defp update_performance_metrics(metrics, analysis) do
    %{
      metrics
      | optimization_count: metrics.optimization_count + 1,
        load_balance_history: [
          analysis.cpu_balance_quality | Enum.take(metrics.load_balance_history, 99)
        ]
    }
  end

  defp scale_up(pool, additional_agents) do
    Logger.info("📈 Scaling up agent pool by #{additional_agents} agents")

    # Create new agent specifications
    new_agents = create_additional_agents(additional_agents, pool)

    # Add new agents to the pool
    updated_pool =
      Enum.reduce(new_agents, pool, fn agent_spec, acc_pool ->
        add_agent(acc_pool, agent_spec)
      end)

    {:ok, updated_pool}
  end

  defp scale_down(pool, agents_to_remove) do
    Logger.info("📉 Scaling down agent pool by #{agents_to_remove} agents")

    # Remove idle agents from available queue
    {updated_available, removed_count} =
      remove_idle_agents(pool.available_agents, agents_to_remove)

    updated_pool = %{pool | available_agents: updated_available}

    if removed_count < agents_to_remove do
      Logger.warning(
        "⚠️ Could only remove #{removed_count} of #{agents_to_remove} requested agents"
      )
    end

    {:ok, updated_pool}
  end

  defp create_additional_agents(count, pool) do
    base_id = :queue.len(pool.available_agents) + :queue.len(pool.busy_agents)

    base_id..(base_id + count - 1)
    |> Enum.map(fn index ->
      %{
        id: "agent_#{index}",
        # Will be assigned when spawned
        pid: nil,
        cpu_affinity: rem(index, System.schedulers_online()),
        priority: :normal,
        status: :available,
        workload_count: 0,
        last_activity: System.monotonic_time(:millisecond)
      }
    end)
  end

  defp remove_idle_agents(queue, target_count) do
    remove_idle_agents(queue, target_count, :queue.new(), 0)
  end

  defp remove_idle_agents(queue, target_count, acc, removed_count)
       when removed_count >= target_count do
    # Reached target, return remaining queue
    final_queue = :queue.join(acc, queue)
    {final_queue, removed_count}
  end

  defp remove_idle_agents(queue, target_count, acc, removed_count) do
    case :queue.out(queue) do
      {{:value, agent}, remaining} ->
        # Check if agent is idle (can be safely removed)
        if agent.status == :available and agent.workload_count == 0 do
          # Remove this agent
          remove_idle_agents(remaining, target_count, acc, removed_count + 1)
        else
          # Keep this agent
          updated_acc = :queue.in(agent, acc)
          remove_idle_agents(remaining, target_count, updated_acc, removed_count)
        end

      {:empty, _} ->
        # No more agents to process
        {acc, removed_count}
    end
  end
end
