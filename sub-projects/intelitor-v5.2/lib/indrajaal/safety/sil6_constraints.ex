defmodule Indrajaal.Safety.SIL6Constraints do
  @moduledoc """
  SIL-6 Biomorphic Mesh Safety Constraints
  =========================================

  Defines and validates 18 new STAMP constraints for SIL-6 compliance:
  - SC-SWARM-001 to SC-SWARM-005: Swarm algorithm safety
  - SC-OBS-001 to SC-OBS-005: Observability requirements
  - SC-BIO-001 to SC-BIO-005: Biomorphic execution
  - SC-MESH-001 to SC-MESH-003: Mesh topology constraints

  ## SIL-6 Requirements (Beyond SIL-4)
  | Metric | SIL-4 | SIL-6 |
  |--------|-------|-------|
  | PFH | <10^-8 | <10^-12 |
  | Diagnostic Coverage | >99% | >99.99% |
  | Safe Failure Fraction | >99% | >99.9% |
  | Response Time | <100ms | <50ms |

  ## Usage

      {:ok, reg} = Indrajaal.Safety.STAMPRegistry.start_link(name: :stamp_registry)
      Indrajaal.Safety.SIL6Constraints.register_all(reg)

      # Validate swarm operation
      {:ok, _} = STAMPRegistry.validate(reg, "SC-SWARM-001", swarm_action)
  """

  require Logger
  alias Indrajaal.Safety.STAMPRegistry

  @sil6_constraints %{
    # Swarm Algorithm Constraints (SC-SWARM-*)
    "SC-SWARM-001" => %{
      description: "Swarm algorithms MUST converge within 1000 iterations",
      category: :swarm,
      severity: :high,
      validator: &__MODULE__.validate_swarm_convergence/1
    },
    "SC-SWARM-002" => %{
      description: "Swarm population size MUST be between 10 and 1000",
      category: :swarm,
      severity: :high,
      validator: &__MODULE__.validate_swarm_population/1
    },
    "SC-SWARM-003" => %{
      description: "Swarm fitness diversity MUST be maintained above 0.1",
      category: :swarm,
      severity: :medium,
      validator: &__MODULE__.validate_swarm_diversity/1
    },
    "SC-SWARM-004" => %{
      description: "Swarm consensus level MUST reach 0.8 for decision",
      category: :swarm,
      severity: :high,
      validator: &__MODULE__.validate_swarm_consensus/1
    },
    "SC-SWARM-005" => %{
      description: "Swarm decisions MUST be logged to Immutable Register",
      category: :swarm,
      severity: :critical,
      validator: &__MODULE__.validate_swarm_logging/1
    },

    # Observability Constraints (SC-OBS-*)
    "SC-OBS-001" => %{
      description: "All telemetry events MUST include trace_id",
      category: :observability,
      severity: :high,
      validator: &__MODULE__.validate_trace_id/1
    },
    "SC-OBS-002" => %{
      description: "Loki push latency MUST be under 100ms p99",
      category: :observability,
      severity: :medium,
      validator: &__MODULE__.validate_loki_latency/1
    },
    "SC-OBS-003" => %{
      description: "Prometheus metrics MUST be scraped every 15s",
      category: :observability,
      severity: :medium,
      validator: &__MODULE__.validate_prometheus_scrape/1
    },
    "SC-OBS-004" => %{
      description: "OTEL spans MUST propagate context across services",
      category: :observability,
      severity: :high,
      validator: &__MODULE__.validate_context_propagation/1
    },
    "SC-OBS-005" => %{
      description: "Circuit breaker MUST open after 5 consecutive failures",
      category: :observability,
      severity: :critical,
      validator: &__MODULE__.validate_circuit_breaker/1
    },

    # Biomorphic Execution Constraints (SC-BIO-*)
    "SC-BIO-001" => %{
      description: "OODA cycle MUST complete in under 100ms",
      category: :biomorphic,
      severity: :critical,
      validator: &__MODULE__.validate_ooda_cycle/1
    },
    "SC-BIO-002" => %{
      description: "Quality gate MUST achieve 80% minimum score",
      category: :biomorphic,
      severity: :high,
      validator: &__MODULE__.validate_quality_gate/1
    },
    "SC-BIO-003" => %{
      description: "Agent scaling MUST respect API rate limits (70% target)",
      category: :biomorphic,
      severity: :critical,
      validator: &__MODULE__.validate_api_rate_limit/1
    },
    "SC-BIO-004" => %{
      description: "Context window MUST compact at 75% usage",
      category: :biomorphic,
      severity: :high,
      validator: &__MODULE__.validate_context_compaction/1
    },
    "SC-BIO-005" => %{
      description: "Dashboard MUST refresh every 30 seconds",
      category: :biomorphic,
      severity: :medium,
      validator: &__MODULE__.validate_dashboard_refresh/1
    },

    # Mesh Topology Constraints (SC-MESH-*)
    "SC-MESH-001" => %{
      description: "2oo3 voting MUST be active for production actuations",
      category: :mesh,
      severity: :critical,
      validator: &__MODULE__.validate_2oo3_voting/1
    },
    "SC-MESH-002" => %{
      description: "Zenoh mesh quorum MUST be floor(N/2)+1",
      category: :mesh,
      severity: :critical,
      validator: &__MODULE__.validate_mesh_quorum/1
    },
    "SC-MESH-003" => %{
      description: "Apoptosis MUST follow 6-phase protocol",
      category: :mesh,
      severity: :high,
      validator: &__MODULE__.validate_apoptosis_protocol/1
    }
  }

  @doc """
  Returns all SIL-6 constraint definitions.
  """
  @spec constraints() :: map()
  def constraints, do: @sil6_constraints

  @doc """
  Registers all SIL-6 constraints with the STAMP registry.
  """
  @spec register_all(GenServer.server()) :: :ok
  def register_all(registry) do
    Enum.each(@sil6_constraints, fn {id, attrs} ->
      STAMPRegistry.register(registry, id, attrs)
    end)

    Logger.info("[SIL6Constraints] Registered #{map_size(@sil6_constraints)} constraints")
    :ok
  end

  @doc """
  Validates an action against all SIL-6 constraints.
  Returns {:ok, results} or {:error, violations}.
  """
  @spec validate_all(GenServer.server(), map()) :: {:ok, list()} | {:error, list()}
  def validate_all(registry, action) do
    results =
      @sil6_constraints
      |> Map.keys()
      |> Enum.map(fn id ->
        case STAMPRegistry.validate(registry, id, action) do
          {:ok, constraint} -> {:pass, id, constraint}
          {:error, :constraint_violated} -> {:fail, id, nil}
          {:error, :not_found} -> {:skip, id, nil}
        end
      end)

    failures = Enum.filter(results, fn {status, _, _} -> status == :fail end)

    if failures == [] do
      {:ok, results}
    else
      {:error, Enum.map(failures, fn {_, id, _} -> id end)}
    end
  end

  @doc """
  Returns SIL-6 compliance metrics.
  """
  @spec metrics() :: map()
  def metrics do
    %{
      total_constraints: map_size(@sil6_constraints),
      by_category: group_by_category(),
      by_severity: group_by_severity(),
      sil_level: 6,
      pfh_target: "10^-12",
      diagnostic_coverage: "99.99%",
      safe_failure_fraction: "99.9%",
      response_time_ms: 50
    }
  end

  # ============================================================================
  # VALIDATORS
  # ============================================================================

  @doc false
  def validate_swarm_convergence(%{iterations: iterations}) when is_integer(iterations) do
    iterations <= 1000
  end

  def validate_swarm_convergence(_), do: true

  @doc false
  def validate_swarm_population(%{population_size: size}) when is_integer(size) do
    size >= 10 and size <= 1000
  end

  def validate_swarm_population(_), do: true

  @doc false
  def validate_swarm_diversity(%{diversity: diversity}) when is_number(diversity) do
    diversity >= 0.1
  end

  def validate_swarm_diversity(_), do: true

  @doc false
  def validate_swarm_consensus(%{consensus_level: level}) when is_number(level) do
    level >= 0.8
  end

  def validate_swarm_consensus(_), do: true

  @doc false
  def validate_swarm_logging(%{logged: logged}) when is_boolean(logged) do
    logged == true
  end

  def validate_swarm_logging(%{register_entry: entry}) when is_map(entry) do
    Map.has_key?(entry, :hash) and Map.has_key?(entry, :timestamp)
  end

  def validate_swarm_logging(_), do: true

  @doc false
  def validate_trace_id(%{trace_id: trace_id}) when is_binary(trace_id) do
    byte_size(trace_id) > 0
  end

  def validate_trace_id(%{metadata: %{trace_id: trace_id}}) when is_binary(trace_id) do
    byte_size(trace_id) > 0
  end

  def validate_trace_id(_), do: true

  @doc false
  def validate_loki_latency(%{latency_ms: latency}) when is_number(latency) do
    latency < 100
  end

  def validate_loki_latency(_), do: true

  @doc false
  def validate_prometheus_scrape(%{scrape_interval_ms: interval}) when is_integer(interval) do
    interval <= 15_000
  end

  def validate_prometheus_scrape(_), do: true

  @doc false
  def validate_context_propagation(%{parent_span_id: parent_id, span_id: span_id})
      when is_binary(parent_id) and is_binary(span_id) do
    byte_size(parent_id) > 0 and byte_size(span_id) > 0
  end

  def validate_context_propagation(_), do: true

  @doc false
  def validate_circuit_breaker(%{failure_count: count, circuit_state: state}) do
    if count >= 5, do: state == :open, else: true
  end

  def validate_circuit_breaker(_), do: true

  @doc false
  def validate_ooda_cycle(%{cycle_duration_ms: duration}) when is_number(duration) do
    duration < 100
  end

  def validate_ooda_cycle(_), do: true

  @doc false
  def validate_quality_gate(%{quality_score: score}) when is_number(score) do
    score >= 0.8 or score >= 80
  end

  def validate_quality_gate(_), do: true

  @doc false
  def validate_api_rate_limit(%{rate_usage_percent: usage}) when is_number(usage) do
    usage <= 70
  end

  def validate_api_rate_limit(_), do: true

  @doc false
  def validate_context_compaction(%{context_usage_percent: usage, compacted: compacted}) do
    if usage >= 75, do: compacted == true, else: true
  end

  def validate_context_compaction(_), do: true

  @doc false
  def validate_dashboard_refresh(%{refresh_interval_s: interval}) when is_number(interval) do
    interval <= 30
  end

  def validate_dashboard_refresh(_), do: true

  @doc false
  def validate_2oo3_voting(%{voting_mode: mode, environment: :production}) do
    mode == "2oo3"
  end

  def validate_2oo3_voting(%{voting_active: active, environment: :production}) do
    active == true
  end

  def validate_2oo3_voting(_), do: true

  @doc false
  def validate_mesh_quorum(%{node_count: n, quorum: q}) when is_integer(n) and is_integer(q) do
    q >= div(n, 2) + 1
  end

  def validate_mesh_quorum(_), do: true

  @doc false
  def validate_apoptosis_protocol(%{phase: phase, phases_completed: completed})
      when is_atom(phase) and is_list(completed) do
    required_phases = [
      :initiated,
      :notifying,
      :draining,
      :checkpointing,
      :terminating,
      :terminated
    ]

    case phase do
      :terminated -> Enum.all?(required_phases, &(&1 in completed))
      _ -> true
    end
  end

  def validate_apoptosis_protocol(_), do: true

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  defp group_by_category do
    @sil6_constraints
    |> Enum.group_by(fn {_id, attrs} -> attrs.category end)
    |> Enum.map(fn {cat, items} -> {cat, length(items)} end)
    |> Map.new()
  end

  defp group_by_severity do
    @sil6_constraints
    |> Enum.group_by(fn {_id, attrs} -> attrs.severity end)
    |> Enum.map(fn {sev, items} -> {sev, length(items)} end)
    |> Map.new()
  end
end
