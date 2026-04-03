defmodule Indrajaal.Observability.DynamicResourceAllocator do
  @moduledoc """
  Dynamic Resource Allocator - Intelligent Resource Distribution

  WHAT: Allocates system resources (processes, memory, I/O) dynamically
        based on current load, predictions, and priority tiers.

  WHY: Ensures optimal performance across all 8 fractal layers while
       preventing resource starvation and maintaining SIL-6 guarantees.

  DESIGN (PID Controller + Adaptive Thresholds):
    - P (Proportional): React to current deviation from target
    - I (Integral): Account for accumulated error over time
    - D (Derivative): Anticipate future trends

  RESOURCE POOLS:
    - :compute  - BEAM schedulers and process limits
    - :memory   - Heap allocation and GC tuning
    - :io       - File descriptors and network connections
    - :storage  - Disk I/O and cache space

  PRIORITY TIERS (SIL-6 Compliant):
    1. Constitutional - Guardian, Sentinel, FPPS (NEVER throttle)
    2. Safety - Alarms, Emergency, Health checks
    3. Core - Business logic, API handlers
    4. Background - Analytics, Reporting, Cleanup
    5. Optional - Telemetry detail, Debug logging

  STAMP Constraints:
    - SC-RES-001: Constitutional tier gets 100% allocation always
    - SC-RES-002: Resource decisions < 10ms
    - SC-RES-003: Graceful shedding from tier 5 to tier 2
    - SC-RES-004: No tier 1 degradation under any circumstance
    - SC-RES-005: Predictive scaling with 5-minute horizon
  """

  use GenServer
  require Logger
  alias Indrajaal.Observability.HomeostaticController
  alias Indrajaal.Observability.IntelligentKPIAggregator

  # Allocation cycle interval
  @allocation_interval_ms 2_000

  # PID controller gains (tuned for BEAM)
  # Proportional gain
  @kp 0.5
  # Integral gain
  @ki 0.1
  # Derivative gain
  @kd 0.05

  # Resource pools with limits
  @resource_limits %{
    compute: %{
      max_processes: 1_000_000,
      scheduler_threads: 16,
      process_spawn_rate: 10_000
    },
    memory: %{
      max_heap_mb: 8192,
      gc_minor_threshold: 1024,
      gc_major_threshold: 4096
    },
    io: %{
      max_file_descriptors: 65536,
      max_connections: 10_000,
      io_threads: 16
    },
    storage: %{
      cache_size_mb: 1024,
      write_buffer_mb: 256,
      max_disk_io_mbps: 500
    }
  }

  # Priority tier definitions
  @priority_tiers %{
    constitutional: %{
      weight: 1.0,
      min_allocation: 1.0,
      max_allocation: 1.0,
      shedding_enabled: false
    },
    safety: %{
      weight: 0.9,
      min_allocation: 0.8,
      max_allocation: 1.0,
      shedding_enabled: false
    },
    core: %{
      weight: 0.7,
      min_allocation: 0.3,
      max_allocation: 1.0,
      shedding_enabled: true
    },
    background: %{
      weight: 0.4,
      min_allocation: 0.1,
      max_allocation: 0.8,
      shedding_enabled: true
    },
    optional: %{
      weight: 0.2,
      min_allocation: 0.0,
      max_allocation: 0.5,
      shedding_enabled: true
    }
  }

  # ============================================================================
  # State Structure
  # ============================================================================

  defstruct allocations: %{},
            pid_state: %{},
            shedding_level: 0,
            predictions: %{},
            decisions: [],
            last_allocation: nil,
            subscribers: []

  # ============================================================================
  # Client API
  # ============================================================================

  @doc "Start the Dynamic Resource Allocator"
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Get current allocation for a tier"
  @spec get_allocation(atom()) :: float()
  def get_allocation(tier) do
    GenServer.call(__MODULE__, {:get_allocation, tier})
  catch
    :exit, _ -> 1.0
  end

  @doc "Get all current allocations"
  @spec allocations() :: map()
  def allocations do
    GenServer.call(__MODULE__, :allocations)
  catch
    :exit, _ -> %{}
  end

  @doc "Get current shedding level (0-100)"
  @spec shedding_level() :: non_neg_integer()
  def shedding_level do
    GenServer.call(__MODULE__, :shedding_level)
  catch
    :exit, _ -> 0
  end

  @doc "Check if a feature tier is active"
  @spec tier_active?(atom()) :: boolean()
  def tier_active?(tier) do
    GenServer.call(__MODULE__, {:tier_active?, tier})
  catch
    :exit, _ -> true
  end

  @doc "Get resource budget for a specific pool"
  @spec pool_budget(atom()) :: map()
  def pool_budget(pool) do
    GenServer.call(__MODULE__, {:pool_budget, pool})
  catch
    :exit, _ -> %{}
  end

  @doc "Request resource allocation for a task"
  @spec request_resources(atom(), map()) :: {:ok, map()} | {:rejected, String.t()}
  def request_resources(tier, requirements) do
    GenServer.call(__MODULE__, {:request, tier, requirements})
  catch
    :exit, _ -> {:rejected, "Allocator unavailable"}
  end

  @doc "Release previously allocated resources"
  @spec release_resources(reference()) :: :ok
  def release_resources(allocation_ref) do
    GenServer.cast(__MODULE__, {:release, allocation_ref})
  end

  @doc "Get recent allocation decisions"
  @spec recent_decisions() :: [map()]
  def recent_decisions do
    GenServer.call(__MODULE__, :recent_decisions)
  catch
    :exit, _ -> []
  end

  @doc "Subscribe to allocation changes"
  @spec subscribe(pid()) :: :ok
  def subscribe(pid \\ self()) do
    GenServer.cast(__MODULE__, {:subscribe, pid})
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(_opts) do
    state = %__MODULE__{
      allocations: init_allocations(),
      pid_state: init_pid_state(),
      shedding_level: 0,
      predictions: %{},
      decisions: [],
      last_allocation: DateTime.utc_now(),
      subscribers: []
    }

    # Schedule allocation cycle
    Process.send_after(self(), :allocate, @allocation_interval_ms)

    Logger.info(
      "[DynamicResourceAllocator] Started - managing 4 resource pools, 5 priority tiers"
    )

    {:ok, state}
  end

  @impl true
  def handle_call({:get_allocation, tier}, _from, state) do
    allocation = get_in(state.allocations, [tier, :current]) || 1.0
    {:reply, allocation, state}
  end

  @impl true
  def handle_call(:allocations, _from, state) do
    {:reply, state.allocations, state}
  end

  @impl true
  def handle_call(:shedding_level, _from, state) do
    {:reply, state.shedding_level, state}
  end

  @impl true
  def handle_call({:tier_active?, tier}, _from, state) do
    allocation = get_in(state.allocations, [tier, :current]) || 1.0
    active = allocation > 0.05
    {:reply, active, state}
  end

  @impl true
  def handle_call({:pool_budget, pool}, _from, state) do
    limits = Map.get(@resource_limits, pool, %{})
    saturation = get_in(state.predictions, [:saturation]) || 0.5

    budget =
      Map.new(limits, fn {key, max_val} ->
        {key, round(max_val * (1 - saturation * 0.3))}
      end)

    {:reply, budget, state}
  end

  @impl true
  def handle_call({:request, tier, requirements}, _from, state) do
    tier_config = Map.get(@priority_tiers, tier, Map.get(@priority_tiers, :optional))
    allocation = get_in(state.allocations, [tier, :current]) || tier_config.min_allocation

    if allocation > 0.1 do
      ref = make_ref()
      granted = scale_requirements(requirements, allocation)

      decision = %{
        type: :grant,
        tier: tier,
        ref: ref,
        requirements: requirements,
        granted: granted,
        timestamp: DateTime.utc_now()
      }

      decisions = [decision | Enum.take(state.decisions, 99)]
      {:reply, {:ok, Map.put(granted, :ref, ref)}, %{state | decisions: decisions}}
    else
      decision = %{
        type: :reject,
        tier: tier,
        reason: "Tier shedded",
        timestamp: DateTime.utc_now()
      }

      decisions = [decision | Enum.take(state.decisions, 99)]
      {:reply, {:rejected, "Tier #{tier} is currently shedded"}, %{state | decisions: decisions}}
    end
  end

  @impl true
  def handle_call(:recent_decisions, _from, state) do
    {:reply, Enum.take(state.decisions, 20), state}
  end

  @impl true
  def handle_cast({:release, _allocation_ref}, state) do
    # Track release (for future use in allocation tracking)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:subscribe, pid}, state) do
    subscribers = [pid | state.subscribers] |> Enum.uniq()
    {:noreply, %{state | subscribers: subscribers}}
  end

  @impl true
  def handle_info(:allocate, state) do
    new_state = perform_allocation_cycle(state)

    # Schedule next cycle
    Process.send_after(self(), :allocate, @allocation_interval_ms)

    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ============================================================================
  # Allocation Logic
  # ============================================================================

  defp perform_allocation_cycle(state) do
    # Collect current metrics
    mode =
      try do
        HomeostaticController.mode()
      catch
        _, _ -> :normal
      end

    kpis =
      try do
        IntelligentKPIAggregator.all_kpis()
      catch
        _, _ -> %{}
      end

    # Calculate target utilization based on mode
    target = mode_to_target(mode)

    # Get current utilization
    current = get_in(kpis, [:saturation, :current]) || 50.0

    # Calculate shedding level
    new_shedding = calculate_shedding_level(mode, current, target)

    # Run PID controller
    {new_pid_state, control_signal} = pid_control(state.pid_state, current, target)

    # Calculate new allocations
    new_allocations = calculate_allocations(control_signal, new_shedding)

    # Record predictions
    new_predictions = %{
      saturation: current / 100,
      trend: get_in(kpis, [:saturation, :trend]) || :stable,
      forecast: get_in(kpis, [:saturation, :forecast_5m]) || current
    }

    # Notify subscribers if significant change
    if significant_change?(state.allocations, new_allocations) do
      notify_subscribers(state.subscribers, {:allocation_change, new_allocations})
    end

    %{
      state
      | allocations: new_allocations,
        pid_state: new_pid_state,
        shedding_level: new_shedding,
        predictions: new_predictions,
        last_allocation: DateTime.utc_now()
    }
  end

  defp mode_to_target(mode) do
    case mode do
      :normal -> 70.0
      :recovery -> 60.0
      :stressed -> 50.0
      :degraded -> 40.0
      :critical -> 30.0
      _ -> 60.0
    end
  end

  defp calculate_shedding_level(mode, current, target) do
    base =
      case mode do
        :critical -> 80
        :degraded -> 50
        :stressed -> 30
        _ -> 0
      end

    # Add more shedding if over target
    overshoot = max(0, (current - target) / 100 * 50)

    min(100, round(base + overshoot))
  end

  defp pid_control(pid_state, current, target) do
    error = target - current
    prev_error = Map.get(pid_state, :prev_error, error)
    integral = Map.get(pid_state, :integral, 0)

    # PID calculation
    p_term = @kp * error
    i_term = @ki * (integral + error)
    d_term = @kd * (error - prev_error)

    control_signal = p_term + i_term + d_term

    # Anti-windup: limit integral
    new_integral = max(-100, min(100, integral + error))

    new_state = %{
      prev_error: error,
      integral: new_integral,
      last_output: control_signal
    }

    {new_state, control_signal}
  end

  defp calculate_allocations(control_signal, shedding_level) do
    # Control signal: positive = need more resources, negative = can shed

    Map.new(@priority_tiers, fn {tier, config} ->
      base_allocation =
        if config.shedding_enabled do
          # Apply shedding
          shedding_factor = 1 - shedding_level / 100
          config.weight * shedding_factor
        else
          # No shedding for critical tiers
          config.weight
        end

      # Apply control signal adjustment
      adjusted = base_allocation + control_signal / 100 * 0.2

      # Clamp to tier limits
      final = max(config.min_allocation, min(config.max_allocation, adjusted))

      {tier,
       %{
         current: final,
         target: config.weight,
         min: config.min_allocation,
         max: config.max_allocation,
         shedding_enabled: config.shedding_enabled
       }}
    end)
  end

  defp scale_requirements(requirements, allocation) do
    Map.new(requirements, fn {key, value} ->
      case value do
        v when is_number(v) -> {key, round(v * allocation)}
        _ -> {key, value}
      end
    end)
  end

  defp significant_change?(old_allocs, new_allocs) do
    Enum.any?(@priority_tiers, fn {tier, _} ->
      old = get_in(old_allocs, [tier, :current]) || 1.0
      new = get_in(new_allocs, [tier, :current]) || 1.0
      abs(old - new) > 0.1
    end)
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp init_allocations do
    Map.new(@priority_tiers, fn {tier, config} ->
      {tier,
       %{
         current: config.weight,
         target: config.weight,
         min: config.min_allocation,
         max: config.max_allocation,
         shedding_enabled: config.shedding_enabled
       }}
    end)
  end

  defp init_pid_state do
    %{
      prev_error: 0,
      integral: 0,
      last_output: 0
    }
  end

  defp notify_subscribers(subscribers, message) do
    Enum.each(subscribers, fn pid ->
      if Process.alive?(pid) do
        send(pid, {:resource_allocator, message})
      end
    end)
  end
end
