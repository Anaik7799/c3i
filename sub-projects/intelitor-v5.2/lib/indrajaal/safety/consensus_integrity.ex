defmodule Indrajaal.Safety.ConsensusIntegrity do
  @moduledoc """
  Mathematical Integrity Metrics — High-Fidelity System State Quantification.

  ## WHAT
  Computes and tracks the four mathematical integrity metrics that quantify
  system health from an information-theoretic perspective. Provides the raw
  metric feeds that ConsensusAggregator uses for its integrity score.

  ## WHY
  Traditional health checks (CPU, memory, error rate) miss deeper structural
  properties. Information-theoretic metrics detect subtle degradation patterns
  that manifest as drift, loss of self-similarity, or entropy accumulation
  before they become visible as errors.

  ## Metrics (CLAUDE.md §111.0)
  - **H_s (Structural Entropy)**: Shannon entropy across fractal layers
  - **epsilon (Homeostatic Drift)**: Deviation from metabolic target (80% CPU)
  - **D_s (Fractal Similarity)**: Self-similarity coefficient across L0-L7
  - **M_dot (Metabolic Velocity)**: Mutation throughput per hour

  ## CONSTRAINTS
  - SC-MATH-001: Discipline health monitored
  - SC-MATH-002: Token ratios validated
  - SC-VER-001: Startup verification before ready

  ## Document Control
  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2026-03-24 |
  | Author | Cybernetic Architect |
  | STAMP | SC-MATH-001, SC-MATH-002 |
  """

  require Logger

  @metabolic_target 0.80
  @ets_table :consensus_integrity_metrics

  # ── Public API ──────────────────────────────────────────────────────

  @doc """
  Initializes the ETS table for metric storage. Call once at startup.
  """
  @spec init() :: :ok
  def init do
    if :ets.whereis(@ets_table) == :undefined do
      :ets.new(@ets_table, [:named_table, :set, :public, read_concurrency: true])
      :ets.insert(@ets_table, {:mutation_count, 0})
      :ets.insert(@ets_table, {:last_snapshot, nil})
    end

    :ok
  end

  @doc """
  Computes all four integrity metrics and returns them as a map.

  ## Returns
  ```
  %{
    structural_entropy: float(),    # H_s — Shannon entropy
    homeostatic_drift: float(),     # epsilon — deviation from 80%
    fractal_similarity: float(),    # D_s — self-similarity [0,1]
    metabolic_velocity: float()     # M_dot — mutations/hour
  }
  ```
  """
  @spec compute_metrics() :: map()
  def compute_metrics do
    %{
      structural_entropy: compute_structural_entropy(),
      homeostatic_drift: compute_homeostatic_drift(),
      fractal_similarity: compute_fractal_similarity(),
      metabolic_velocity: compute_metabolic_velocity()
    }
  end

  @doc """
  Records a mutation event for metabolic velocity tracking.
  """
  @spec record_mutation() :: :ok
  def record_mutation do
    ensure_initialized()

    :ets.update_counter(@ets_table, :mutation_count, {2, 1})
    :ok
  rescue
    ArgumentError -> :ok
  end

  @doc """
  Takes a snapshot of current metrics for trend analysis.
  Returns the snapshot and stores it in ETS.
  """
  @spec snapshot() :: map()
  def snapshot do
    ensure_initialized()

    metrics = compute_metrics()

    snapshot = Map.put(metrics, :timestamp, System.monotonic_time(:millisecond))

    :ets.insert(@ets_table, {:last_snapshot, snapshot})
    metrics
  end

  @doc """
  Returns the last snapshot, or `nil` if none taken.
  """
  @spec last_snapshot() :: map() | nil
  def last_snapshot do
    ensure_initialized()

    case :ets.lookup(@ets_table, :last_snapshot) do
      [{:last_snapshot, snap}] -> snap
      [] -> nil
    end
  rescue
    ArgumentError -> nil
  end

  # ── H_s: Structural Entropy ────────────────────────────────────────
  #
  # Shannon entropy across the 7 fractal layers (L0-L7).
  # Measures the "disorder" in how system components are distributed.
  # Lower entropy = more concentrated/ordered; Higher = more uniform/distributed.

  @doc """
  Computes Shannon entropy across fractal layers.

  H_s = -sum(p_i * log2(p_i)) for each layer i

  Where p_i = proportion of system activity at layer i.
  """
  @spec compute_structural_entropy() :: float()
  def compute_structural_entropy do
    # Approximate layer distribution from runtime observables
    layer_weights = estimate_layer_distribution()

    total = Enum.sum(Map.values(layer_weights))

    if total > 0 do
      layer_weights
      |> Map.values()
      |> Enum.map(fn w ->
        p = w / total

        if p > 0 do
          -p * :math.log(p) / :math.log(2)
        else
          0.0
        end
      end)
      |> Enum.sum()
    else
      0.0
    end
  end

  # ── epsilon: Homeostatic Drift ──────────────────────────────────────
  #
  # Deviation from the metabolic target (80% CPU utilization).
  # The system aims for 80% saturation — not too idle, not too hot.

  @doc """
  Computes homeostatic drift from the 80% metabolic target.

  epsilon = |current_utilization - 0.80|
  """
  @spec compute_homeostatic_drift() :: float()
  def compute_homeostatic_drift do
    current_utilization = get_cpu_utilization()
    abs(current_utilization - @metabolic_target)
  end

  # ── D_s: Fractal Similarity ────────────────────────────────────────
  #
  # Self-similarity coefficient across L0-L7.
  # A healthy fractal system shows similar patterns at each scale.

  @doc """
  Computes fractal similarity coefficient (0.0 to 1.0).

  D_s = 1 - CV(layer_health_scores)

  Where CV = coefficient of variation of health across layers.
  """
  @spec compute_fractal_similarity() :: float()
  def compute_fractal_similarity do
    layer_health = estimate_layer_health()
    values = Map.values(layer_health)

    if length(values) > 1 do
      mean = Enum.sum(values) / length(values)

      if mean > 0 do
        variance =
          values
          |> Enum.map(fn v -> (v - mean) * (v - mean) end)
          |> Enum.sum()
          |> Kernel./(length(values))

        std_dev = :math.sqrt(variance)
        cv = std_dev / mean

        # Similarity is inverse of variation, clamped to [0, 1]
        max(min(1.0 - cv, 1.0), 0.0)
      else
        0.0
      end
    else
      1.0
    end
  end

  # ── M_dot: Metabolic Velocity ──────────────────────────────────────
  #
  # Mutation throughput per hour. Tracks how fast the system is evolving.

  @doc """
  Computes metabolic velocity (mutations per hour).

  M_dot = mutation_count / elapsed_hours
  """
  @spec compute_metabolic_velocity() :: float()
  def compute_metabolic_velocity do
    ensure_initialized()

    mutation_count =
      case :ets.lookup(@ets_table, :mutation_count) do
        [{:mutation_count, count}] -> count
        [] -> 0
      end

    # Use BEAM uptime as elapsed time
    uptime_ms = :erlang.statistics(:wall_clock) |> elem(0)
    uptime_hours = max(uptime_ms / 3_600_000, 0.001)

    mutation_count / uptime_hours
  rescue
    ArgumentError -> 0.0
  end

  # ── Layer Estimation ────────────────────────────────────────────────

  defp estimate_layer_distribution do
    process_count = :erlang.system_info(:process_count)
    ets_count = length(:ets.all())
    port_count = length(Port.list())

    %{
      l0_runtime: process_count * 0.3,
      l1_function: process_count * 0.2,
      l2_component: ets_count * 1.0,
      l3_holon: process_count * 0.15,
      l4_container: port_count * 1.0,
      l5_node: process_count * 0.1,
      l6_cluster: process_count * 0.05,
      l7_federation: process_count * 0.02
    }
  end

  defp estimate_layer_health do
    memory = :erlang.memory()
    total = max(memory[:total] || 1, 1)
    process_mem_ratio = (memory[:processes] || 0) / total

    # Approximate health at each layer
    base_health = 1.0 - min(process_mem_ratio * 2, 0.8)

    %{
      l0: base_health,
      l1: base_health * 0.95,
      l2: base_health * 0.90,
      l3: base_health * 0.92,
      l4: base_health * 0.88,
      l5: base_health * 0.85,
      l6: base_health * 0.80,
      l7: base_health * 0.78
    }
  end

  defp get_cpu_utilization do
    try do
      {total, _} = :erlang.statistics(:reductions)
      # Normalize: 100M reductions ≈ 80% utilization on 16-core
      min(total / 100_000_000, 1.0)
    rescue
      _ -> 0.5
    end
  end

  defp ensure_initialized do
    if :ets.whereis(@ets_table) == :undefined do
      init()
    end
  end
end
