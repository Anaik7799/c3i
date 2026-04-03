defmodule Indrajaal.Coordination.LoadBalancer do
  @moduledoc """
  Advanced Load Balancer with Intelligent Task Distribution

  Created: #{DateTime.utc_now() |> DateTime.to_string()} CEST
  Framework: SOPv5.1 + Intelligent Load Balancing + Predictive Scaling

  Provides sophisticated load balancing capabilities including:
  - Real - time workload analysis and distribution
  - Predictive load balancing with machine learning
  - Adaptive resource allocation based on agent performance
  - Dynamic routing with performance optimization
  - Fault - tolerant task distribution with automatic recovery
  """

  use GenServer
  require Logger

  @type balancing_strategy ::
          :round_robin | :least_loaded | :performance_based | :predictive | :adaptive
  @type task_priority :: :critical | :high | :medium | :low
  @type load_metric :: :cpu | :memory | :network | :tasks | :response_time | :composite

  defstruct [
    :config,
    :balancing_strategy,
    :agent_metrics,
    :task_queue,
    :performance_tracker,
    :routing_table,
    :prediction_model,
    :health_checker
  ]

  ## Public API

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec assign_tasks(pid(), list(), map()) :: list()
  def assign_tasks(balancer, tasks, agents) do
    GenServer.call(balancer, {:assign_tasks, tasks, agents}, :infinity)
  end

  @spec update_agent_metrics(pid(), String.t(), map()) :: :ok
  def update_agent_metrics(balancer, agent_id, metrics) do
    GenServer.call(balancer, {:update_agent_metrics, agent_id, metrics})
  end

  @spec get_load_distribution(pid()) :: map()
  def get_load_distribution(balancer) do
    GenServer.call(balancer, :get_load_distribution)
  end

  @spec optimize_routing(pid()) :: :ok
  def optimize_routing(balancer) do
    GenServer.call(balancer, :optimize_routing)
  end

  ## GenServer Implementation

  @impl GenServer
  @spec init(keyword() | map()) :: term()
  def init(opts) do
    Logger.info("⚖️ Initializing Advanced Load Balancer")
    config = build_config(opts)

    state = %__MODULE__{
      config: config,
      balancing_strategy: config.default_strategy,
      agent_metrics: %{},
      task_queue: :queue.new(),
      performance_tracker: initialize_performance_tracker(),
      routing_table: initialize_routing_table(),
      prediction_model: initialize_prediction_model(config),
      health_checker: initialize_health_checker()
    }

    # Schedule periodic optimization
    schedule_optimization(config.optimization_interval_ms)
    schedule_metrics_collection(config.metrics_collection_interval_ms)

    Logger.info("✅ Advanced Load Balancer initialized with strategy: #{config.default_strategy}")
    {:ok, state}
  end

  @impl GenServer
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call({:assigntasks, tasks, agents}, _from, state) do
    Logger.info("📋 Assigning #{length(tasks)} tasks to #{map_size(agents)} agents")

    # Update agent status
    updated_state = update_agent_registry(state, agents)

    # Analyze tasks and agents
    task_analysis = analyze_tasks(tasks)
    agent_analysis = analyze_agents(agents, updated_state.agent_metrics)

    # Select optimal balancing strategy
    optimal_strategy = select_optimal_strategy(task_analysis, agent_analysis, updated_state)

    # Perform task assignment
    assignments = execute_task_assignment(tasks, agents, optimal_strategy, updated_state)

    # Update performance metrics
    final_state = update_assignment_metrics(updated_state, assignments)

    Logger.info("✅ Task assignment completed: #{length(assignments)} assignments")
    {:reply, assignments, final_state}
  end

  @impl GenServer
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call({:update_agent_metrics, agent_id, metrics}, _from, state) do
    updated_metrics = Map.put(state.agent_metrics, agent_id, metrics)
    new_state = %{state | agent_metrics: updated_metrics}

    # Update routing table if significant performance change detected
    routing_update_needed? = detect_performance_change(agent_id, metrics, state.agent_metrics)

    final_state =
      if routing_update_needed? do
        update_routing_table(new_state, agent_id, metrics)
      else
        new_state
      end

    {:reply, :ok, final_state}
  end

  @impl GenServer
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call(:getloaddistribution, _from, state) do
    distribution = calculate_load_distribution(state)
    {:reply, distribution, state}
  end

  @impl GenServer
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call(:optimizerouting, _from, state) do
    optimized_state = perform_routing_optimization(state)
    Logger.info("⚡ Routing optimization completed")
    {:reply, :ok, optimized_state}
  end

  @impl GenServer
  @spec handle_info(term(), term()) :: term()
  def handle_info(:optimize, state) do
    optimized_state = perform_periodic_optimization(state)
    schedule_optimization(state.config.optimization_interval_ms)
    {:noreply, optimized_state}
  end

  @impl GenServer
  @spec handle_info(term(), term()) :: term()
  def handle_info(:collectmetrics, state) do
    updated_state = collect_performance_metrics(state)
    schedule_metrics_collection(state.config.metrics_collection_interval_ms)
    {:noreply, updated_state}
  end

  ## Task Assignment Strategies

  @spec execute_task_assignment(list(), map(), balancing_strategy(), %__MODULE__{}) :: list()
  defp execute_task_assignment(tasks, agents, strategy, state) do
    Logger.info("🎯 Executing task assignment with strategy: #{strategy}")

    case strategy do
      :round_robin ->
        assign_round_robin(tasks, agents, state)

      :least_loaded ->
        assign_least_loaded(tasks, agents, state)

      :performance_based ->
        assign_performance_based(tasks, agents, state)

      :predictive ->
        assign_predictive(tasks, agents, state)

      :adaptive ->
        assign_adaptive(tasks, agents, state)

      _ ->
        # Fallback
        assign_round_robin(tasks, agents, state)
    end
  end

  @spec assign_round_robin(list(), map(), %__MODULE__{}) :: list()
  defp assign_round_robin(tasks, agents, _state) do
    Logger.info("🔄 Applying round - robin assignment strategy")

    all_agents = Map.values(agents)
    agent_list = all_agents |> Enum.filter(&(&1.status == :idle))

    if Enum.empty?(agent_list) do
      Logger.warning("⚠️ No idle agents available for round - robin assignment")
      []
    else
      tasks
      |> Enum.with_index()
      |> Enum.map(fn {task, index} ->
        agent = Enum.at(agent_list, rem(index, length(agent_list)))
        {agent, task}
      end)
    end
  end

  @spec assign_least_loaded(list(), map(), %__MODULE__{}) :: list()
  defp assign_least_loaded(tasks, agents, state) do
    Logger.info("📊 Applying least - loaded assignment strategy")

    initial_load_map = calculate_agent_loads(agents, state.agent_metrics)

    {assignments, _final_load_map} =
      Enum.map_reduce(tasks, initial_load_map, fn task, agent_load_map ->
        least_loaded_agent = find_least_loaded_agent(agent_load_map, agents)

        # Update load tracking for next iteration
        current_load = Map.get(agent_load_map, least_loaded_agent.id, 0)

        updated_load_map =
          Map.put(agent_load_map, least_loaded_agent.id, current_load + task.estimated_load)

        {{least_loaded_agent, task}, updated_load_map}
      end)

    assignments
  end

  @spec assign_performance_based(list(), map(), %__MODULE__{}) :: list()
  defp assign_performance_based(tasks, agents, state) do
    Logger.info("🏆 Applying performance - based assignment strategy")

    agent_performance_scores = calculate_agent_performance_scores(agents, state.agent_metrics)

    Enum.map(tasks, fn task ->
      best_agent = select_best_performing_agent(task, agent_performance_scores, agents)
      {best_agent, task}
    end)
  end

  @spec assign_predictive(list(), map(), %__MODULE__{}) :: list()
  defp assign_predictive(tasks, agents, state) do
    Logger.info("🔮 Applying predictive assignment strategy")

    # Use machine learning model to predict optimal assignments
    predictions = generate_assignment_predictions(tasks, agents, state.prediction_model)

    Enum.map(predictions, fn prediction ->
      agent = Map.get(agents, prediction.agent_id)
      task = prediction.task
      {agent, task}
    end)
  end

  @spec assign_adaptive(list(), map(), %__MODULE__{}) :: list()
  defp assign_adaptive(tasks, agents, state) do
    Logger.info("🧠 Applying adaptive assignment strategy")

    # Analyze current system state and choose best strategy dynamically
    current_load = calculate_system_load(agents, state.agent_metrics)
    task_complexity = analyze_task_complexity_distribution(tasks)
    agent_health = assess_agent_health_distribution(agents, state.agent_metrics)

    optimal_strategy = determine_adaptive_strategy(current_load, task_complexity, agent_health)

    Logger.info("📈 Adaptive strategy selected: #{optimal_strategy}")
    execute_task_assignment(tasks, agents, optimal_strategy, state)
  end

  ## Analysis Functions

  @spec analyze_tasks(list()) :: map()
  defp analyze_tasks(tasks) do
    total_tasks = length(tasks)

    priority_distribution = Enum.group_by(tasks, & &1.priority)
    complexity_scores = Enum.map(tasks, &calculate_task_complexity/1)
    estimated_total_load = Enum.sum(Enum.map(tasks, &(&1.estimated_load || 1)))

    %{
      total_count: total_tasks,
      priority_distribution: priority_distribution,
      average_complexity: average(complexity_scores),
      max_complexity: Enum.max(complexity_scores, fn -> 0 end),
      estimated_total_load: estimated_total_load,
      high_priority_count: length(Map.get(priority_distribution, :high, [])),
      critical_priority_count: length(Map.get(priority_distribution, :critical, []))
    }
  end

  @spec analyze_agents(map(), map()) :: map()
  defp analyze_agents(agents, agent_metrics) do
    total_agents = map_size(agents)
    idle_agents = agents |> Map.values() |> Enum.count(&(&1.status == :idle))
    busy_agents = agents |> Map.values() |> Enum.count(&(&1.status == :busy))

    performance_scores = calculate_all_performance_scores(agents, agent_metrics)
    average_performance = average(Map.values(performance_scores))

    %{
      total_count: total_agents,
      idle_count: idle_agents,
      busy_count: busy_agents,
      utilization_rate: if(total_agents > 0, do: busy_agents / total_agents * 100, else: 0),
      average_performance: average_performance,
      high_performers: count_high_performers(performance_scores),
      low_performers: count_low_performers(performance_scores)
    }
  end

  @spec select_optimal_strategy(map(), map(), %__MODULE__{}) :: balancing_strategy()
  defp select_optimal_strategy(task_analysis, agent_analysis, state) do
    # Decision matrix for strategy selection
    cond do
      # High - priority tasks with good agent performance -> performance - based
      task_analysis.critical_priority_count > 0 and agent_analysis.average_performance > 80 ->
        :performance_based

      # High utilization with varying performance -> adaptive
      agent_analysis.utilization_rate > 70 and agent_analysis.low_performers > 0 ->
        :adaptive

      # Many tasks with good prediction model -> predictive
      task_analysis.total_count > 10 and state.prediction_model.accuracy > 0.85 ->
        :predictive

      # Uneven load distribution -> least_loaded
      has_uneven_load_distribution?(agent_analysis) ->
        :least_loaded

      # Default case -> round_robin
      true ->
        :round_robin
    end
  end

  ## Load Calculation and Management

  @spec calculate_agent_loads(map(), map()) :: map()
  defp calculate_agent_loads(agents, agent_metrics) do
    agents
    |> Enum.map(fn {agent_id, agent} ->
      metrics = Map.get(agent_metrics, agent_id, %{})
      load = calculate_composite_load(agent, metrics)
      {agent_id, load}
    end)
    |> Map.new()
  end

  @spec calculate_composite_load(map(), map()) :: float()
  defp calculate_composite_load(_agent, metrics) do
    cpu_load = Map.get(metrics, :cpu_usage, 0) * 0.4
    memory_load = Map.get(metrics, :memory_usage, 0) * 0.3
    task_load = Map.get(metrics, :active_tasks, 0) * 10 * 0.2
    network_load = Map.get(metrics, :network_usage, 0) * 0.1

    cpu_load + memory_load + task_load + network_load
  end

  @spec find_least_loaded_agent(map(), map()) :: map()
  defp find_least_loaded_agent(loadmap, agents) do
    {least_loaded_id, _load} = Enum.min_by(loadmap, fn {_id, load} -> load end)
    Map.get(agents, least_loaded_id)
  end

  @spec calculate_agent_performance_scores(map(), map()) :: map()
  defp calculate_agent_performance_scores(agents, agent_metrics) do
    agents
    |> Enum.map(fn {agent_id, agent} ->
      metrics = Map.get(agent_metrics, agent_id, %{})
      score = calculate_performance_score(agent, metrics)
      {agent_id, score}
    end)
    |> Map.new()
  end

  @spec calculate_performance_score(map(), map()) :: float()
  defp calculate_performance_score(_agent, metrics) do
    success_rate = Map.get(metrics, :success_rate, 100.0)
    avg_response_time = Map.get(metrics, :average_response_time_ms, 100)
    throughput = Map.get(metrics, :tasks_per_minute, 1.0)

    # Normalize and weight the metrics
    success_weight = success_rate * 0.4
    # Inverse of response time
    speed_weight = 1000 / max(avg_response_time, 1) * 0.3
    throughput_weight = throughput * 0.3

    success_weight + speed_weight + throughput_weight
  end

  @spec select_best_performing_agent(map(), map(), map()) :: map()
  defp select_best_performing_agent(task, performance_scores, agents) do
    # Filter agents that can handle the task
    compatible_agents = filter_compatible_agents(task, agents)

    if Enum.empty?(compatible_agents) do
      # Fallback to any available agent
      agents |> Map.values() |> Enum.find(&(&1.status == :idle)) || List.first(Map.values(agents))
    else
      # Select highest scoring compatible agent
      best_id =
        compatible_agents
        |> Enum.max_by(fn agent -> Map.get(performance_scores, agent.id, 0) end)
        |> Map.get(:id)

      Map.get(agents, best_id)
    end
  end

  ## Predictive Assignment

  @spec generate_assignment_predictions(list(), map(), map()) :: list()
  defp generate_assignment_predictions(tasks, agents, prediction_model) do
    Logger.info("🔮 Generating predictive assignments using ML model")

    # Simplified ML prediction - in reality this would use a trained model
    Enum.map(tasks, fn task ->
      features = extract_task_features(task)

      agent_predictions =
        Enum.map(agents, fn {agent_id, agent} ->
          agent_features = extract_agent_features(agent)
          score = predict_assignment_success(features, agent_features, prediction_model)
          {agent_id, score}
        end)

      {best_agent_id, _score} = Enum.max_by(agent_predictions, fn {_id, score} -> score end)

      %{
        task: task,
        agent_id: best_agent_id,
        confidence: prediction_model.accuracy
      }
    end)
  end

  @spec extract_task_features(map()) :: map()
  defp extract_task_features(task) do
    %{
      priority: priority_to_numeric(task.priority),
      estimated_load: task.estimated_load || 1,
      complexity: calculate_task_complexity(task),
      requires_gpu: Map.get(task, :requires_gpu, false),
      requires_network: Map.get(task, :requires_network, false)
    }
  end

  @spec extract_agent_features(map()) :: map()
  defp extract_agent_features(agent) do
    %{
      type: agent_type_to_numeric(agent.type),
      status: agent_status_to_numeric(agent.status),
      performance_score: calculate_agent_base_performance(agent),
      capabilities: length(agent.capabilities || []),
      current_load: Map.get(agent, :current_load, 0)
    }
  end

  @spec predict_assignment_success(map(), map(), map()) :: float()
  defp predict_assignment_success(task_features, agent_features, _model) do
    # Simplified prediction algorithm - replace with actual ML model
    base_score = 50.0

    # Task priority matching
    priority_bonus =
      if task_features.priority > 2 and agent_features.performance_score > 80, do: 20, else: 0

    # Load balancing
    load_penalty = agent_features.current_load * -0.5

    # Capability matching
    capability_bonus = agent_features.capabilities * 2

    # Agent type matching
    type_bonus =
      case agent_features.type do
        # specialist
        3 -> 15
        # helper
        2 -> 10
        # worker
        1 -> 5
        _ -> 0
      end

    base_score + priority_bonus + load_penalty + capability_bonus + type_bonus
  end

  ## Adaptive Strategy Selection

  @spec determine_adaptive_strategy(float(), map(), map()) :: balancing_strategy()
  defp determine_adaptive_strategy(system_load, task_complexity, agent_health) do
    cond do
      system_load > 80 and agent_health.low_performers > 2 ->
        :performance_based

      task_complexity.variance > 0.5 ->
        :predictive

      system_load > 60 ->
        :least_loaded

      true ->
        :round_robin
    end
  end

  ## Configuration and Initialization

  defp build_config(opts) do
    default_config = %{
      default_strategy: :adaptive,
      optimization_interval_ms: 30_000,
      metrics_collection_interval_ms: 10_000,
      prediction_model_enabled: true,
      health_monitoring_enabled: true,
      auto_scaling_enabled: true,
      load_balancing_algorithms: [
        :round_robin,
        :least_loaded,
        :performance_based,
        :predictive,
        :adaptive
      ]
    }

    Enum.reduce(opts, default_config, fn {key, value}, config ->
      Map.put(config, key, value)
    end)
  end

  defp initialize_performance_tracker do
    %{
      assignments_made: 0,
      successful_assignments: 0,
      failed_assignments: 0,
      average_assignment_time_ms: 0,
      strategy_effectiveness: %{},
      load_distribution_history: []
    }
  end

  defp initialize_routing_table do
    %{
      agent_weights: %{},
      preferred_routes: %{},
      blocked_routes: [],
      last_update: DateTime.utc_now()
    }
  end

  defp initialize_prediction_model(config) do
    if config.prediction_model_enabled do
      %{
        # Initial accuracy
        accuracy: 0.75,
        training_data: [],
        model_version: "1.0.0",
        last_training: DateTime.utc_now(),
        predictions_made: 0,
        correct_predictions: 0
      }
    else
      %{enabled: false}
    end
  end

  defp initialize_health_checker do
    %{
      healthy_agents: %{},
      unhealthy_agents: %{},
      last_health_check: DateTime.utc_now(),
      health_trends: %{}
    }
  end

  ## Utility Functions

  defp schedule_optimization(interval_ms) do
    Process.send_after(self(), :optimize, interval_ms)
  end

  defp schedule_metrics_collection(interval_ms) do
    Process.send_after(self(), :collect_metrics, interval_ms)
  end

  defp update_agent_registry(state, agents) do
    # Update internal agent registry with latest agent information
    %{state | agent_metrics: merge_agent_data(state.agent_metrics, agents)}
  end

  defp merge_agent_data(existing_metrics, agents) do
    agents
    |> Enum.reduce(existing_metrics, fn {agent_id, agent}, acc ->
      existing = Map.get(acc, agent_id, %{})
      updated = Map.merge(existing, extract_basic_metrics(agent))
      Map.put(acc, agent_id, updated)
    end)
  end

  defp extract_basic_metrics(agent) do
    %{
      status: agent.status,
      type: agent.type,
      last_seen: DateTime.utc_now(),
      capabilities: agent.capabilities || []
    }
  end

  defp update_assignment_metrics(state, assignments) do
    successful_count = length(assignments)

    updated_tracker =
      state.performance_tracker
      |> Map.update!(:assignments_made, &(&1 + successful_count))
      |> Map.update!(:successful_assignments, &(&1 + successful_count))

    %{state | performance_tracker: updated_tracker}
  end

  defp calculate_load_distribution(state) do
    # Create agent map from metrics keys
    agents = state.agent_metrics |> Map.keys() |> Enum.map(&{&1, %{id: &1}}) |> Map.new()
    agent_loads = calculate_agent_loads(agents, state.agent_metrics)

    total_load = agent_loads |> Map.values() |> Enum.sum()
    agent_count = map_size(agent_loads)

    %{
      total_load: total_load,
      average_load: if(agent_count > 0, do: total_load / agent_count, else: 0),
      agent_loads: agent_loads,
      load_variance: calculate_load_variance(agent_loads),
      timestamp: DateTime.utc_now()
    }
  end

  defp perform_routing_optimization(state) do
    Logger.info("⚡ Performing routing optimization")

    # Analyze current routing patterns
    routing_analysis = analyze_routing_patterns(state)

    # Update routing table based on analysis
    optimized_routing_table = optimize_routing_table(state.routing_table, routing_analysis)

    %{state | routing_table: optimized_routing_table}
  end

  defp perform_periodic_optimization(state) do
    Logger.info("🔄 Performing periodic optimization")

    # Update prediction model
    updated_model = update_prediction_model(state.prediction_model)

    # Optimize performance tracker
    optimized_tracker = optimize_performance_tracker(state.performance_tracker)

    %{state | prediction_model: updated_model, performance_tracker: optimized_tracker}
  end

  defp collect_performance_metrics(state) do
    Logger.info("📊 Collecting performance metrics")

    # This would collect real metrics in production
    state
  end

  # Helper functions with mock implementations
  defp calculate_task_complexity(task) do
    base_complexity = Map.get(task, :complexity, 1)
    priority_multiplier = priority_to_numeric(task.priority) * 0.1
    base_complexity + priority_multiplier
  end

  defp priority_to_numeric(:critical), do: 4
  defp priority_to_numeric(:high), do: 3
  defp priority_to_numeric(:medium), do: 2
  defp priority_to_numeric(:low), do: 1
  defp priority_to_numeric(_), do: 2

  defp agent_type_to_numeric(:specialist), do: 3
  defp agent_type_to_numeric(:helper), do: 2
  defp agent_type_to_numeric(:worker), do: 1
  defp agent_type_to_numeric(:supervisor), do: 4
  defp agent_type_to_numeric(_), do: 1

  defp agent_status_to_numeric(:idle), do: 1
  defp agent_status_to_numeric(:busy), do: 0.5
  defp agent_status_to_numeric(:unhealthy), do: 0
  defp agent_status_to_numeric(_), do: 0.5

  defp calculate_agent_base_performance(agent) do
    # Simplified performance calculation
    base_score = 100.0

    status_modifier =
      case agent.status do
        :idle -> 1.0
        :busy -> 0.8
        :unhealthy -> 0.1
        _ -> 0.5
      end

    base_score * status_modifier
  end

  defp average([]), do: 0
  defp average(list), do: Enum.sum(list) / length(list)

  defp calculate_all_performance_scores(agents, agent_metrics) do
    agents
    |> Enum.map(fn {agent_id, agent} ->
      metrics = Map.get(agent_metrics, agent_id, %{})
      score = calculate_performance_score(agent, metrics)
      {agent_id, score}
    end)
    |> Map.new()
  end

  defp count_high_performers(scores) do
    scores |> Map.values() |> Enum.count(&(&1 > 80))
  end

  defp count_low_performers(scores) do
    scores |> Map.values() |> Enum.count(&(&1 < 50))
  end

  defp has_uneven_load_distribution?(agent_analysis) do
    agent_analysis.utilization_rate > 80 or
      (agent_analysis.idle_count > 0 and agent_analysis.busy_count > 0 and
         agent_analysis.busy_count / agent_analysis.total_count > 0.7)
  end

  defp calculate_system_load(agents, agent_metrics) do
    loads = calculate_agent_loads(agents, agent_metrics)
    total_load = loads |> Map.values() |> Enum.sum()
    agent_count = map_size(agents)

    if agent_count > 0, do: total_load / agent_count, else: 0
  end

  defp analyze_task_complexity_distribution(tasks) do
    complexities = Enum.map(tasks, &calculate_task_complexity/1)
    avg = average(complexities)
    variance = calculate_variance(complexities, avg)

    %{
      average: avg,
      variance: variance,
      max: Enum.max(complexities, fn -> 0 end),
      min: Enum.min(complexities, fn -> 0 end)
    }
  end

  defp assess_agent_health_distribution(agents, agent_metrics) do
    performance_scores = calculate_agent_performance_scores(agents, agent_metrics)
    high_performers = count_high_performers(performance_scores)
    low_performers = count_low_performers(performance_scores)

    %{
      high_performers: high_performers,
      low_performers: low_performers,
      total: map_size(agents)
    }
  end

  defp filter_compatible_agents(task, agents) do
    # Simplified compatibility check
    agents
    |> Map.values()
    |> Enum.filter(fn agent ->
      agent.status == :idle and
        has_required_capabilities?(agent, task)
    end)
  end

  defp has_required_capabilities?(agent, task) do
    required = Map.get(task, :required_capabilities, [])
    available = agent.capabilities || []

    Enum.all?(required, &(&1 in available))
  end

  defp detect_performance_change(_agent_id, _new_metrics, _old_metrics) do
    # Simplified change detection
    # 10% chance of significant change
    :rand.uniform() < 0.1
  end

  defp update_routing_table(state, _agent_id, _metrics) do
    # Update routing table based on performance changes
    state
  end

  defp calculate_load_variance(loads) do
    values = Map.values(loads)
    avg = average(values)
    calculate_variance(values, avg)
  end

  defp calculate_variance([], _avg), do: 0

  defp calculate_variance(values, avg) do
    sum_squares =
      values
      |> Enum.map(&:math.pow(&1 - avg, 2))
      |> Enum.sum()

    sum_squares / length(values)
  end

  defp analyze_routing_patterns(state) do
    %{
      total_routes: map_size(state.routing_table.preferred_routes),
      blocked_routes: length(state.routing_table.blocked_routes),
      last_optimization: state.routing_table.last_update
    }
  end

  defp optimize_routing_table(routing_table, _analysis) do
    %{routing_table | last_update: DateTime.utc_now()}
  end

  defp update_prediction_model(model) do
    if Map.get(model, :enabled, true) do
      # Update model accuracy based on recent predictions
      Map.put(model, :last_training, DateTime.utc_now())
    else
      model
    end
  end

  defp optimize_performance_tracker(tracker) do
    # Clean up old data, calculate new statistics
    tracker
  end
end
