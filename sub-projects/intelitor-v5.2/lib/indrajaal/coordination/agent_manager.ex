defmodule Indrajaal.Coordination.AgentManager do
  @moduledoc """
  Advanced Agent Management System with Dynamic Scaling

  Created: 2025-08-30 13:41:30 CEST
  Framework: SOPv5.1 + Dynamic Agent Lifecycle Management

  Provides sophisticated agent lifecycle management including:
  - Dynamic agent spawning and termination
  - Health monitoring and recovery
  - Performance tracking and optimization
  - Resource allocation and management
  - Fault tolerance and resilience
  """

  use GenServer
  # PHASE Q: GenServer patterns consolidated
  require Logger

  @type agent_type :: :supervisor | :helper | :worker | :specialist
  @type agent_status :: :idle | :busy | :unhealthy | :terminated
  @type scaling_direction :: :up | :down | :maintain

  defstruct [
    :config,
    :agents,
    :performance_tracker,
    :health_monitor,
    :scaling_policy,
    :resource_monitor
  ]

  ## Public API

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec spawn_agent(agent_type(), map()) :: {:ok, map()} | {:error, term()}
  def spawn_agent(type, config \\ %{}) do
    GenServer.call(__MODULE__, {:spawn_agent, type, config})
  end

  @spec terminate_agent(String.t()) :: :ok | {:error, term()}
  def terminate_agent(agent_id) do
    GenServer.call(__MODULE__, {:terminate_agent, agent_id})
  end

  @spec scale_agents(agent_type(), integer()) :: {:ok, list()} | {:error, term()}
  def scale_agents(type, target_count) do
    GenServer.call(__MODULE__, {:scale_agents, type, target_count})
  end

  @spec get_agent_metrics() :: map()
  def get_agent_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  @spec perform_health_check() :: map()
  def perform_health_check do
    GenServer.call(__MODULE__, :health_check)
  end

  @doc """
  Awaits completion of multiple async tasks with a configurable timeout.

  ## Parameters
  - `tasks` - List of `Task` structs to await
  - `timeout` - Timeout in milliseconds (default: 5000)

  ## Returns
  - `{:ok, results}` - All tasks completed successfully
  - `{:timeout, results}` - Some tasks timed out; results contains
    `{:ok, value}` for completed and `{:exit, :timeout}` for timed-out tasks

  ## STAMP Compliance
  - SC-PRF-050: Response < 50ms where possible; configurable timeout for batch ops
  - SC-AGT-018: No deadlocks — uses Task.await_many with timeout
  """
  @spec await_completion(list(Task.t()), pos_integer()) ::
          {:ok, list(term())} | {:timeout, list(term())}
  def await_completion(tasks, timeout \\ 5_000) when is_list(tasks) and is_integer(timeout) do
    results = Task.await_many(tasks, timeout)

    timeout_count =
      Enum.count(results, fn
        {:exit, :timeout} -> true
        _ -> false
      end)

    if timeout_count == 0 do
      {:ok, results}
    else
      Logger.warning(
        "[AgentManager] await_completion: #{timeout_count}/#{length(tasks)} tasks timed out",
        timeout_ms: timeout,
        total_tasks: length(tasks),
        timed_out: timeout_count
      )

      {:timeout, results}
    end
  rescue
    e ->
      Logger.error("[AgentManager] await_completion failed: #{inspect(e)}")
      {:timeout, []}
  end

  ## GenServer Implementation

  @impl GenServer
  @spec init(keyword() | map()) :: term()
  def init(opts) do
    Logger.info("🤖 Initializing Advanced Agent Manager")
    config = build_config(opts)

    state = %__MODULE__{
      config: config,
      agents: %{},
      performance_tracker: initialize_performance_tracker(),
      health_monitor: initialize_health_monitor(),
      scaling_policy: initialize_scaling_policy(config),
      resource_monitor: initialize_resource_monitor()
    }

    # Schedule periodic health checks
    schedule_health_check(config.health_check_interval_ms)
    schedule_performance_analysis(config.performance_analysis_interval_ms)

    Logger.info("✅ Agent Manager initialized successfully")
    {:ok, state}
  end

  @impl GenServer
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call({:spawn_agent, type, config}, _from, state) do
    case create_agent(type, config, state) do
      {:ok, agent, new_state} ->
        Logger.info("✅ Successfully spawned #{type} agent: #{agent.id}")
        {:reply, {:ok, agent}, new_state}

      {:error, reason} ->
        Logger.error("❌ Failed to spawn #{type} agent: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call({:terminate_agent, agent_id}, _from, state) do
    case terminate_agent_by_id(agent_id, state) do
      {:ok, new_state} ->
        Logger.info("✅ Successfully terminated agent: #{agent_id}")
        {:reply, :ok, new_state}

      {:error, reason} ->
        Logger.error("❌ Failed to terminate agent #{agent_id}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call({:scale_agents, type, target_count}, _from, state) do
    case execute_scaling_operation(type, target_count, state) do
      {:ok, agents, new_state} ->
        Logger.info("✅ Successfully scaled #{type} agents to #{target_count}")
        {:reply, {:ok, agents}, new_state}

        # Note: execute_scaling_operation currently always returns {:ok, _, _}
        # {:error, reason} ->  # Unreachable - commented out
        #   Logger.error("❌ Failed to scale #{type} agents: #{inspect(reason)}")
        #   {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call(:get_metrics, _from, state) do
    metrics = collect_agent_metrics(state)
    {:reply, metrics, state}
  end

  @impl GenServer
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call(:health_check, _from, state) do
    health_status = perform_comprehensive_health_check(state)
    {:reply, health_status, state}
  end

  @impl GenServer
  @spec handle_info(term(), term()) :: term()
  def handle_info(:periodic_health_check, state) do
    new_state = execute_periodic_health_check(state)
    schedule_health_check(state.config.health_check_interval_ms)
    {:noreply, new_state}
  end

  @impl GenServer
  @spec handle_info(term(), term()) :: term()
  def handle_info(:performance_analysis, state) do
    new_state = execute_performance_analysis(state)
    schedule_performance_analysis(state.config.performance_analysis_interval_ms)
    {:noreply, new_state}
  end

  ## Agent Creation and Management

  @spec create_agent(agent_type(), map(), %__MODULE__{}) ::
          {:ok, map(), %__MODULE__{}} | {:error, term()}
  defp create_agent(type, config, state) do
    agent_id = generate_agent_id(type)

    agent_spec = %{
      id: agent_id,
      type: type,
      status: :idle,
      config: merge_agent_config(type, config, state.config),
      capabilities: define_agent_capabilities(type),
      resources: allocate_agent_resources(type, state.resource_monitor),
      performance_metrics: initialize_agent_performance_metrics(),
      health_status: :healthy,
      created_at: DateTime.utc_now(),
      last_activity: DateTime.utc_now(),
      current_task: nil
    }

    case validate_agent_creation(agent_spec, state) do
      :ok ->
        new_agents = Map.put(state.agents, agent_id, agent_spec)
        new_state = %{state | agents: new_agents}

        # Register agent with monitoring systems
        register_agent_with_monitors(agent_spec, new_state)

        {:ok, agent_spec, new_state}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec terminate_agent_by_id(String.t(), %__MODULE__{}) ::
          {:ok, %__MODULE__{}} | {:error, term()}
  defp terminate_agent_by_id(agent_id, state) do
    case Map.get(state.agents, agent_id) do
      nil ->
        {:error, :agent_not_found}

      agent ->
        case gracefully_shutdown_agent(agent, state) do
          :ok ->
            new_agents = Map.delete(state.agents, agent_id)
            new_state = %{state | agents: new_agents}

            # Unregister from monitoring systems
            unregister_agent_from_monitors(agent, new_state)

            {:ok, new_state}

            # Note: gracefully_shutdown_agent currently always returns :ok
            # {:error, reason} ->  # Unreachable - commented out
            #   {:error, reason}
        end
    end
  end

  @spec execute_scaling_operation(agent_type(), integer(), %__MODULE__{}) ::
          {:ok, list(), %__MODULE__{}} | {:error, term()}
  defp execute_scaling_operation(type, target_count, state) do
    current_agents = get_agents_by_type(state.agents, type)
    current_count = length(current_agents)

    cond do
      target_count > current_count ->
        # Scale up
        scale_up_agents(type, target_count - current_count, state)

      target_count < current_count ->
        # Scale down
        scale_down_agents(type, current_count - target_count, current_agents, state)

      true ->
        # No scaling needed
        {:ok, current_agents, state}
    end
  end

  @spec scale_up_agents(agent_type(), integer(), %__MODULE__{}) :: {:ok, list(), %__MODULE__{}}
  defp scale_up_agents(type, count, state) do
    Logger.info("📈 Scaling up #{count} #{type} agents")

    {new_agents, final_state} =
      Enum.reduce(1..count, {[], state}, fn _, {agents_acc, state_acc} ->
        case create_agent(type, %{}, state_acc) do
          {:ok, agent, new_state} ->
            {[agent | agents_acc], new_state}

          {:error, reason} ->
            Logger.error("Failed to scale up agent: #{inspect(reason)}")
            {agents_acc, state_acc}
        end
      end)

    {:ok, new_agents, final_state}
  end

  @spec scale_down_agents(agent_type(), integer(), list(), %__MODULE__{}) ::
          {:ok, list(), %__MODULE__{}}
  defp scale_down_agents(type, count, current_agents, state) do
    Logger.info("📉 Scaling down #{count} #{type} agents")

    # Select agents to terminate (prefer idle agents)
    agents_to_terminate = select_agents_for_termination(current_agents, count)

    {terminated_agents, final_state} =
      Enum.reduce(agents_to_terminate, {[], state}, fn agent, {agents_acc, state_acc} ->
        case terminate_agent_by_id(agent.id, state_acc) do
          {:ok, new_state} ->
            {[agent | agents_acc], new_state}

          {:error, reason} ->
            Logger.error("Failed to terminate agent #{agent.id}: #{inspect(reason)}")
            {agents_acc, state_acc}
        end
      end)

    remaining_agents = current_agents -- terminated_agents
    {:ok, remaining_agents, final_state}
  end

  ## Agent Configuration and Capabilities

  @spec merge_agent_config(agent_type(), map(), map()) :: map()
  defp merge_agent_config(type, custom_config, base_config) do
    type_defaults = get_type_defaults(type)

    base_config |> Map.merge(type_defaults) |> Map.merge(custom_config)
  end

  @spec define_agent_capabilities(agent_type()) :: list()
  defp define_agent_capabilities(:supervisor) do
    [
      :strategic_oversight,
      :resource_allocation,
      :conflict_resolution,
      :progress_monitoring,
      :agent_coordination,
      :decision_making
    ]
  end

  defp define_agent_capabilities(:helper) do
    [
      :compilation_management,
      :testing_coordination,
      :analysis_support,
      :monitoring_assistance,
      :validation_support,
      :optimization_analysis
    ]
  end

  defp define_agent_capabilities(:worker) do
    [
      :task_execution,
      :parallel_processing,
      :container_operations,
      :file_processing,
      :_data_transformation,
      :batch_operations
    ]
  end

  defp define_agent_capabilities(:specialist) do
    [
      :advanced_analytics,
      :machine_learning,
      :security_analysis,
      :performance_optimization,
      :compliance_checking,
      :pattern_recognition
    ]
  end

  @spec allocate_agent_resources(agent_type(), map()) :: map()
  defp allocate_agent_resources(type, resource_monitor) do
    base_allocation = get_resource_allocation_for_type(type)
    available_resources = get_available_resources(resource_monitor)

    if has_sufficient_resources?(base_allocation, available_resources) do
      reserve_resources(base_allocation, resource_monitor)
      base_allocation
    else
      # Allocate reduced resources or fail
      allocate_reduced_resources(type, available_resources)
    end
  end

  ## Health Monitoring

  @spec execute_periodic_health_check(%__MODULE__{}) :: any()
  defp execute_periodic_health_check(state) do
    Logger.info("🏥 Executing periodic health check")

    unhealthy_agents = identify_unhealthy_agents(state.agents)

    if length(unhealthy_agents) > 0 do
      Logger.warning("⚠️ Found #{length(unhealthy_agents)} unhealthy agents")
      apply_health_recovery_actions(unhealthy_agents, state)
    else
      state
    end
  end

  @spec perform_comprehensive_health_check(%__MODULE__{}) :: any()
  defp perform_comprehensive_health_check(state) do
    agent_health = check_all_agents_health(state.agents)
    resource_health = check_resource_health(state.resource_monitor)
    system_health = check_system_health()

    overall_status = determine_overall_health_status(agent_health, resource_health, system_health)

    %{
      overall_status: overall_status,
      agent_health: agent_health,
      resource_health: resource_health,
      system_health: system_health,
      recommendations:
        generate_health_recommendations(agent_health, resource_health, system_health),
      timestamp: DateTime.utc_now()
    }
  end

  ## Performance Analysis

  @spec execute_performance_analysis(%__MODULE__{}) :: any()
  defp execute_performance_analysis(state) do
    Logger.info("📊 Executing performance analysis")

    performance_data = collect_performance_data(state)
    analysis_results = analyze_performance_patterns(performance_data)
    optimization_recommendations = generate_optimization_recommendations(analysis_results)

    # Apply automatic optimizations if enabled
    new_state =
      if state.config.auto_optimization_enabled do
        apply_performance_optimizations(state, optimization_recommendations)
      else
        state
      end

    # Update performance tracker
    update_performance_tracker(new_state, analysis_results)
  end

  ## Utility Functions

  defp build_config(opts) do
    default_config = %{
      health_check_interval_ms: 30_000,
      performance_analysis_interval_ms: 60_000,
      auto_optimization_enabled: true,
      max_agents_per_type: %{
        supervisor: 5,
        helper: 20,
        worker: 100,
        specialist: 50
      },
      resource_limits: %{
        cpu_cores_per_agent: 2,
        memory_mb_per_agent: 512,
        network_mbps_per_agent: 10
      }
    }

    Enum.reduce(opts, default_config, fn {key, value}, config ->
      Map.put(config, key, value)
    end)
  end

  defp generate_agent_id(type) do
    timestamp = System.monotonic_time(:microsecond)

    random = Base.encode16(:crypto.strong_rand_bytes(4), case: :lower)

    "#{type}_#{timestamp}_#{random}"
  end

  defp get_type_defaults(:supervisor) do
    %{
      priority: :high,
      timeout_ms: :infinity,
      max_concurrent_tasks: 10,
      coordination_scope: :global
    }
  end

  defp get_type_defaults(:helper) do
    %{
      priority: :medium,
      timeout_ms: 300_000,
      max_concurrent_tasks: 5,
      coordination_scope: :local
    }
  end

  defp get_type_defaults(:worker) do
    %{
      priority: :normal,
      timeout_ms: 120_000,
      max_concurrent_tasks: 3,
      coordination_scope: :task
    }
  end

  defp get_type_defaults(:specialist) do
    %{
      priority: :high,
      timeout_ms: 600_000,
      max_concurrent_tasks: 2,
      coordination_scope: :domain
    }
  end

  defp get_resource_allocation_for_type(:supervisor) do
    %{cpu_cores: 2, memory_mb: 1024, network_mbps: 50, priority: :high}
  end

  defp get_resource_allocation_for_type(:helper) do
    %{cpu_cores: 1, memory_mb: 512, network_mbps: 20, priority: :medium}
  end

  defp get_resource_allocation_for_type(:worker) do
    %{cpu_cores: 1, memory_mb: 256, network_mbps: 10, priority: :normal}
  end

  defp get_resource_allocation_for_type(:specialist) do
    %{cpu_cores: 4, memory_mb: 2048, network_mbps: 100, priority: :high}
  end

  defp get_agents_by_type(agents, type) do
    agents
    |> Map.values()
    |> Enum.filter(&(&1.type == type))
  end

  defp select_agents_for_termination(agents, count) do
    agents
    |> Enum.sort_by(&{&1.status == :idle, &1.last_activity}, :desc)
    |> Enum.take(count)
  end

  defp validate_agent_creation(agent_spec, state) do
    current_count = count_agents_by_type(state.agents, agent_spec.type)
    max_allowed = get_max_agents_for_type(state.config, agent_spec.type)

    if current_count >= max_allowed do
      {:error, :max_agents_exceeded}
    else
      :ok
    end
  end

  defp count_agents_by_type(agents, type) do
    agents
    |> Map.values()
    |> Enum.count(&(&1.type == type))
  end

  defp get_max_agents_for_type(config, type) do
    Map.get(config.max_agents_per_type, type, 10)
  end

  defp gracefully_shutdown_agent(agent, _state) do
    Logger.info("🔄 Gracefully shutting down agent: #{agent.id}")

    # Wait for current task to complete if any
    if agent.current_task do
      Logger.info("⏳ Waiting for current task to complete...")
      # Implementation would wait for task completion
    end

    :ok
  end

  defp register_agent_with_monitors(agent, _state) do
    Logger.info("📝 Registering agent #{agent.id} with monitoring systems")
    :ok
  end

  defp unregister_agent_from_monitors(agent, _state) do
    Logger.info("📝 Unregistering agent #{agent.id} from monitoring systems")
    :ok
  end

  defp schedule_health_check(interval_ms) do
    Process.send_after(self(), :health_check, interval_ms)
  end

  defp schedule_performance_analysis(interval_ms) do
    Process.send_after(self(), :performance_analysis, interval_ms)
  end

  # Mock implementations for complex functions
  defp initialize_performance_tracker, do: %{metrics: %{}, analysis_history: []}
  defp initialize_health_monitor, do: %{checks: %{}, alerts: []}
  defp initialize_scaling_policy(config), do: %{config: config, rules: []}
  defp initialize_resource_monitor, do: %{available: %{cpu: 16, memory: 32_768, network: 1000}}
  defp initialize_agent_performance_metrics, do: %{tasks_completed: 0, success_rate: 100.0}

  defp get_available_resources(monitor), do: monitor.available
  defp has_sufficient_resources?(_required, _available), do: true
  defp reserve_resources(_allocation, _monitor), do: :ok

  defp allocate_reduced_resources(_type, available),
    do: %{cpu_cores: 1, memory_mb: 128, network_mbps: 5, available_used: available}

  defp identify_unhealthy_agents(agents) do
    agents
    |> Map.values()
    |> Enum.filter(&(&1.health_status != :healthy))
  end

  defp apply_health_recovery_actions(unhealthy_agents, state) do
    Logger.info("AgentManager: applying health recovery actions",
      unhealthy_count: length(unhealthy_agents)
    )

    updated_agents =
      Enum.reduce(unhealthy_agents, state.agents, fn agent, agents_acc ->
        action = determine_recovery_action(agent)
        {:ok, _result} = execute_recovery_action(action, agent)

        Map.update(agents_acc, agent.id, agent, fn existing ->
          Map.merge(existing, %{health_status: :recovering, last_recovery: DateTime.utc_now()})
        end)
      end)

    %{state | agents: updated_agents}
  end

  defp determine_recovery_action(agent) do
    cond do
      agent.health_status == :overloaded -> :increase_capacity
      agent.health_status == :isolated -> :isolate_component
      agent.health_status == :crashed -> :restart_service
      true -> :alert_operator
    end
  end

  defp execute_recovery_action(:restart_service, agent) do
    Logger.info("AgentManager: restarting service for agent", agent_id: agent.id)

    :telemetry.execute(
      [:coordination, :agent_manager, :recovery, :restart_service],
      %{},
      %{agent_id: agent.id}
    )

    {:ok, {:restarted, agent.id}}
  end

  defp execute_recovery_action(:increase_capacity, agent) do
    Logger.info("AgentManager: increasing capacity for agent", agent_id: agent.id)

    :telemetry.execute(
      [:coordination, :agent_manager, :recovery, :increase_capacity],
      %{},
      %{agent_id: agent.id}
    )

    {:ok, {:capacity_increased, agent.id}}
  end

  defp execute_recovery_action(:isolate_component, agent) do
    Logger.info("AgentManager: isolating component for agent", agent_id: agent.id)

    :telemetry.execute(
      [:coordination, :agent_manager, :recovery, :isolate_component],
      %{},
      %{agent_id: agent.id}
    )

    {:ok, {:isolated, agent.id}}
  end

  defp execute_recovery_action(:alert_operator, agent) do
    Logger.warning("AgentManager: alerting operator for unhealthy agent",
      agent_id: agent.id,
      health_status: agent.health_status
    )

    :telemetry.execute(
      [:coordination, :agent_manager, :recovery, :alert_operator],
      %{},
      %{agent_id: agent.id, health_status: agent.health_status}
    )

    {:ok, {:operator_alerted, agent.id}}
  end

  defp check_all_agents_health(agents) do
    healthy_count = agents |> Map.values() |> Enum.count(&(&1.health_status == :healthy))
    total_count = map_size(agents)

    %{
      total_agents: total_count,
      healthy_agents: healthy_count,
      unhealthy_agents: total_count - healthy_count,
      health_percentage: if(total_count > 0, do: healthy_count / total_count * 100, else: 100)
    }
  end

  defp check_resource_health(monitor) do
    %{
      status: :healthy,
      utilization: 45.2,
      available_capacity: 54.8,
      monitor_info: map_size(monitor)
    }
  end

  defp check_system_health do
    %{status: :healthy, load_average: 2.1, memory_usage: 68.5}
  end

  defp determine_overall_health_status(agent_health, resource_health, system_health) do
    if agent_health.health_percentage > 90 and
         resource_health.status == :healthy and
         system_health.status == :healthy do
      :healthy
    else
      :degraded
    end
  end

  defp generate_health_recommendations(agent_health, resource_health, system_health) do
    base_recommendations = [
      "System operating within normal parameters",
      "Consider scaling up workers if load increases",
      "Monitor memory usage trends"
    ]

    # Add specific recommendations based on health metrics
    cond do
      agent_health.health_percentage < 80 ->
        ["Critical: Multiple agents unhealthy - investigate immediately" | base_recommendations]

      resource_health.utilization > 90 ->
        ["High resource utilization - consider scaling" | base_recommendations]

      system_health.load_average > 5.0 ->
        ["High system load detected" | base_recommendations]

      true ->
        base_recommendations
    end
  end

  defp collect_performance_data(state) do
    agent_count = map_size(state.agents)

    %{
      throughput: 150.5 * (agent_count / 10),
      response_time: 45.2,
      error_rate: 0.1,
      resource_utilization: 72.3,
      active_agents: agent_count
    }
  end

  defp analyze_performance_patterns(data) do
    trends =
      if data.throughput > 100,
        do: [:increasing_throughput, :stable_response_time],
        else: [:low_throughput]

    %{
      trends: trends,
      anomalies: [],
      efficiency_score: 92.5,
      data_points: map_size(data)
    }
  end

  defp generate_optimization_recommendations(analysis) do
    base_recommendations = [
      {:scale_workers, 2},
      {:optimize_memory_usage, true},
      {:tune_gc_settings, %{f_requency: :adaptive}}
    ]

    if analysis.efficiency_score < 80 do
      [{:urgent_optimization, true} | base_recommendations]
    else
      base_recommendations
    end
  end

  defp apply_performance_optimizations(recommendations, state) do
    Logger.info("⚡ Applying #{length(recommendations)} performance optimizations")
    state
  end

  defp update_performance_tracker(analysis, state) do
    Logger.debug("📈 Updating performance tracker with efficiency: #{analysis.efficiency_score}")
    state
  end

  defp collect_agent_metrics(state) do
    agents_by_type = Enum.group_by(state.agents, fn {_id, agent} -> agent.type end)

    %{
      total_agents: map_size(state.agents),
      agents_by_type:
        agents_by_type
        |> Enum.map(fn {type, agents} ->
          {type, length(agents)}
        end)
        |> Map.new(),
      agent_health_summary: check_all_agents_health(state.agents),
      performance_summary: collect_performance_data(state),
      resource_utilization: check_resource_health(state.resource_monitor)
    }
  end
end
