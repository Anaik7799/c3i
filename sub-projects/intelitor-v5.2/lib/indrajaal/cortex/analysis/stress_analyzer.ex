defmodule Indrajaal.Cortex.Analysis.StressAnalyzer do
  require Logger

  @moduledoc """
  Analyzes system metrics to calculate a holistic Stress Score (0.0 - 1.0).
  Part of the ORIENT phase of the OODA loop.

  WHAT:
    - Calculates system stress from multiple sensor inputs
    - Provides weighted aggregation of system, compute, ML, and container health
    - Integrates with Podman container health metrics

  WHY:
    - Enables autonomous self-healing decisions based on stress levels
    - Provides holistic view of system health for the Cortex controller
    - Early detection of degraded system state

  CONSTRAINTS:
    - SC-PRF-050: Calculation must complete < 50ms
    - SC-CTX-002: Sensor redundancy (multiple health sources)

  Integration:
    - Uses PodmanHealthSensor for container health ratio
    - Falls back to cluster_status for basic health indication
  """

  @doc """
  Calculates overall system stress based on various sensor inputs.
  Returns a float between 0.0 (idle) and 1.0 (critical overload).

  ## Weights
  - System health: 40% (memory, CPU, processes)
  - Compute load: 25% (FLAME pools)
  - Container health: 25% (Podman container status)
  - ML latency: 10% (inference latency)

  ## Critical Overrides
  - Container stress >= 1.0 -> immediate 1.0 (critical)
  - System stress >= 0.95 -> immediate 1.0 (critical)
  - Container unhealthy count > 0 -> minimum 0.7 (degraded)
  """
  @spec calculate_stress(map()) :: float()
  def calculate_stress(metrics) do
    # Weights for different components
    # System health is paramount (40%)
    # Container health elevated to 25% (infrastructure foundation)
    # Compute load is secondary (25%)
    # ML latency is tertiary (10%)

    system_stress = analyze_system(metrics)
    compute_stress = analyze_compute(metrics)
    ml_stress = analyze_ml(metrics)
    container_stress = analyze_container(metrics)

    # Base weighted score
    base_score =
      system_stress * 0.40 +
        container_stress * 0.25 +
        compute_stress * 0.25 +
        ml_stress * 0.10

    # Critical override: if container is unhealthy or memory is critical, score jumps
    cond do
      container_stress >= 1.0 ->
        1.0

      system_stress >= 0.95 ->
        1.0

      # Degraded state: any unhealthy container means at least 0.7 stress
      get_metric(metrics, :containers_unhealthy) > 0 ->
        max(0.7, base_score)

      # Starting containers indicate potential instability
      get_metric(metrics, :containers_starting) > 0 ->
        max(0.5, base_score)

      true ->
        Float.round(base_score, 3)
    end
  end

  @doc """
  Calculate stress with detailed breakdown for debugging.
  """
  @spec calculate_stress_detailed(map()) :: map()
  def calculate_stress_detailed(metrics) do
    system_stress = analyze_system(metrics)
    compute_stress = analyze_compute(metrics)
    ml_stress = analyze_ml(metrics)
    container_stress = analyze_container(metrics)

    total = calculate_stress(metrics)

    %{
      total: total,
      breakdown: %{
        system: Float.round(system_stress, 3),
        compute: Float.round(compute_stress, 3),
        container: Float.round(container_stress, 3),
        ml: Float.round(ml_stress, 3)
      },
      weights: %{
        system: 0.40,
        container: 0.25,
        compute: 0.25,
        ml: 0.10
      },
      container_details: %{
        total: get_metric(metrics, :containers_total, 0),
        healthy: get_metric(metrics, :containers_healthy, 0),
        unhealthy: get_metric(metrics, :containers_unhealthy, 0),
        starting: get_metric(metrics, :containers_starting, 0),
        health_ratio: get_metric(metrics, :container_health_ratio, 1.0)
      }
    }
  end

  defp analyze_system(metrics) do
    # Memory pressure is the biggest killer of BEAM nodes
    total_memory = get_metric(metrics, :total_memory, 1)

    mem_usage =
      if total_memory > 0, do: get_metric(metrics, :memory_usage) / total_memory, else: 0.5

    # Process limit exhaustion
    proc_usage = get_metric(metrics, :process_utilization)

    # Scheduler usage (CPU)
    cpu_usage = get_metric(metrics, :cpu_usage)

    # Max of memory or process limit (resource exhaustion) averaged with CPU load
    max(mem_usage, proc_usage) * 0.7 + cpu_usage * 0.3
  end

  defp analyze_compute(metrics) do
    # FLAME pool utilization from distributed compute
    # Measures average utilization across all FLAME pools (0.0-1.0)
    # High utilization = high compute stress
    # SC-FLAME-001: Non-blocking polling, SC-FLAME-003: Graceful degradation
    try do
      case Indrajaal.Cortex.Sensors.FLAMESensor.measure() do
        %{avg_utilization: utilization} when is_number(utilization) ->
          # Emit telemetry for metrics collection (SC-FLAME-001, SC-FLAME-003)
          :telemetry.execute(
            [:cortex, :stress, :flame],
            %{utilization: utilization, degraded: false},
            %{component: :flame_pool}
          )

          utilization

        unexpected ->
          # Measurement returned unexpected format - use fallback
          Logger.warning(
            "[StressAnalyzer] FLAME sensor returned unexpected format: #{inspect(unexpected)}, using fallback"
          )

          compute_stress_fallback(metrics)
      end
    rescue
      e ->
        # FLAME sensor not running or error occurred
        # Log warning for visibility (upgraded from debug per SC-FLAME-003)
        Logger.warning(
          "[StressAnalyzer] FLAME sensor unavailable: #{inspect(e)}, using degraded mode"
        )

        :telemetry.execute(
          [:cortex, :stress, :flame],
          %{degraded: true, error: inspect(e)},
          %{component: :flame_pool}
        )

        # Use fallback compute stress estimation
        compute_stress_fallback(metrics)
    end
  end

  # Fallback compute stress estimation when FLAME sensor unavailable
  # Uses scheduler utilization from :erlang.statistics/1 (SC-FLAME-003)
  defp compute_stress_fallback(metrics) do
    try do
      # Get scheduler utilization from BEAM runtime
      scheduler_usage =
        case :erlang.statistics(:scheduler_wall_time_all) do
          :undefined ->
            # Wall time not enabled - try reductions as proxy
            0.0

          times when is_list(times) ->
            # Calculate average scheduler utilization
            {total_active, total_time} =
              Enum.reduce(times, {0, 0}, fn {_id, active, total}, {acc_a, acc_t} ->
                {acc_a + active, acc_t + total}
              end)

            if total_time > 0, do: total_active / total_time, else: 0.0
        end

      # Combine with CPU usage from metrics if available
      cpu_usage = get_metric(metrics, :cpu_usage, 0.0)

      # Weighted average: scheduler gives compute load, CPU gives system load
      stress = scheduler_usage * 0.6 + cpu_usage * 0.4

      :telemetry.execute(
        [:cortex, :stress, :flame],
        %{utilization: stress, degraded: true, source: :fallback},
        %{component: :flame_pool}
      )

      stress
    rescue
      _ ->
        # Ultimate fallback - return 0.0 indicating no stress measurement available
        Logger.debug("[StressAnalyzer] Fallback compute stress estimation failed")
        0.0
    end
  end

  defp analyze_ml(metrics) do
    # Check ETS-backed ML metrics table, then telemetry, then fallback
    ml_latency = get_metric(metrics, :ml_inference_latency_ms)
    ml_queue = get_metric(metrics, :ml_queue_depth)
    ml_errors = get_metric(metrics, :ml_error_rate)

    cond do
      ml_latency > 0 ->
        # Normalize: >500ms = high stress, <50ms = low stress
        min(ml_latency / 500.0, 1.0)

      ml_queue > 0 ->
        # Queue depth stress: >100 items = high stress
        min(ml_queue / 100.0, 1.0)

      ml_errors > 0 ->
        min(ml_errors, 1.0)

      true ->
        # Try Nx/BEAM telemetry for serving metrics
        try do
          case :persistent_term.get({:nx_serving, :metrics}, nil) do
            %{avg_latency_ms: latency} when is_number(latency) ->
              min(latency / 500.0, 1.0)

            _ ->
              0.0
          end
        rescue
          _ -> 0.0
        end
    end
  end

  defp analyze_container(metrics) do
    # Primary: Use container_health_ratio from PodmanHealthSensor if available
    # This is (healthy + no_healthcheck) / total containers
    health_ratio = get_metric(metrics, :container_health_ratio)

    if health_ratio > 0 do
      # Invert: high health ratio = low stress
      1.0 - health_ratio
    else
      # Fallback: Use cluster_status for basic health indication
      case metrics[:cluster_status] do
        :healthy -> 0.0
        :starting -> 0.3
        :degraded -> 0.7
        :unhealthy -> 1.0
        :unknown -> 0.5
        _ -> 0.0
      end
    end
  end

  defp get_metric(map, key, default \\ 0.0) do
    Map.get(map, key, default) || default
  end
end
