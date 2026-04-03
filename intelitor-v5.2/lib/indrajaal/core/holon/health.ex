defmodule Indrajaal.Core.Holon.Health do
  @moduledoc """
  Holon Health - Health Monitoring and Propagation for v20.0.0

  Provides health monitoring for holons:
  1. Health status computation
  2. Health propagation (child → parent)
  3. Health aggregation (children → parent)
  4. Health-based decisions (degradation, recovery)

  ## Health States
  - :healthy - All systems nominal
  - :degraded - Some non-critical issues
  - :critical - Critical issues, limited functionality
  - :failed - Non-functional, requires intervention

  ## Health Propagation Rules
  - Parent health is the WORST of its children's health
  - A single :failed child makes parent at least :critical
  - Majority :degraded children makes parent :degraded

  ## STAMP Constraints
  - SC-HLT-001: Health MUST be computed from VSM states
  - SC-HLT-002: Health changes MUST be reported to parent within 100ms
  - SC-HLT-003: Health MUST be propagated upward only
  - SC-HLT-004: Health recovery MUST have hysteresis
  """

  require Logger

  alias Indrajaal.Core.Holon
  alias Indrajaal.Core.Holon.State

  @type health_report :: %{
          status: Holon.health(),
          details: map(),
          children_summary: map(),
          timestamp: DateTime.t()
        }

  @health_order [:healthy, :degraded, :critical, :failed]

  # Hysteresis: require this many consecutive checks before improving
  @recovery_threshold 3

  @doc """
  Computes the health status from VSM states.
  """
  @spec compute_from_vsm(Holon.vsm_state()) :: Holon.health()
  def compute_from_vsm(vsm) do
    cond do
      vsm_failed?(vsm) -> :failed
      vsm_critical?(vsm) -> :critical
      vsm_degraded?(vsm) -> :degraded
      true -> :healthy
    end
  end

  @doc """
  Aggregates health from a list of child health statuses.
  """
  @spec aggregate([Holon.health()]) :: Holon.health()
  def aggregate([]), do: :healthy

  def aggregate(child_healths) do
    # Parent health is the worst child health
    Enum.max_by(child_healths, &health_priority/1)
  end

  @doc """
  Combines local health with aggregated children health.
  """
  @spec combine(Holon.health(), Holon.health()) :: Holon.health()
  def combine(local_health, children_health) do
    if health_priority(children_health) > health_priority(local_health) do
      children_health
    else
      local_health
    end
  end

  @doc """
  Determines if health has degraded (worsened).
  """
  @spec degraded?(Holon.health(), Holon.health()) :: boolean()
  def degraded?(old_health, new_health) do
    health_priority(new_health) > health_priority(old_health)
  end

  @doc """
  Determines if health has improved.
  """
  @spec improved?(Holon.health(), Holon.health()) :: boolean()
  def improved?(old_health, new_health) do
    health_priority(new_health) < health_priority(old_health)
  end

  @doc """
  Checks health with hysteresis for recovery.

  Requires multiple consecutive "better" checks before reporting improvement.
  """
  @spec check_with_hysteresis(Holon.health(), Holon.health(), non_neg_integer()) ::
          {Holon.health(), non_neg_integer()}
  def check_with_hysteresis(current_health, computed_health, recovery_count) do
    cond do
      # Degradation is immediate
      degraded?(current_health, computed_health) ->
        {computed_health, 0}

      # Improvement requires hysteresis
      improved?(current_health, computed_health) ->
        new_count = recovery_count + 1

        if new_count >= @recovery_threshold do
          {computed_health, 0}
        else
          {current_health, new_count}
        end

      # No change
      true ->
        {current_health, 0}
    end
  end

  @doc """
  Generates a health report for a holon.
  """
  @spec generate_report(State.t(), [Holon.health()]) :: health_report()
  def generate_report(%State{} = state, children_healths \\ []) do
    local_health = compute_from_vsm(state.vsm)
    aggregated = aggregate(children_healths)
    combined = combine(local_health, aggregated)

    %{
      status: combined,
      details: %{
        local_health: local_health,
        aggregated_children: aggregated,
        s1_status: s1_status(state.vsm.s1),
        s2_status: s2_status(state.vsm.s2),
        s3_status: s3_status(state.vsm.s3),
        s4_status: s4_status(state.vsm.s4),
        s5_status: s5_status(state.vsm.s5)
      },
      children_summary: %{
        total: length(children_healths),
        healthy: Enum.count(children_healths, &(&1 == :healthy)),
        degraded: Enum.count(children_healths, &(&1 == :degraded)),
        critical: Enum.count(children_healths, &(&1 == :critical)),
        failed: Enum.count(children_healths, &(&1 == :failed))
      },
      timestamp: DateTime.utc_now()
    }
  end

  @doc """
  Reports health to parent holon.
  """
  @spec report_to_parent(Holon.holon_id(), Holon.holon_id() | nil, Holon.health()) :: :ok
  def report_to_parent(_child_id, nil, _health) do
    # No parent, nothing to report
    :ok
  end

  def report_to_parent(child_id, parent_id, health) do
    # In a real implementation, this would send a message to the parent
    Logger.debug("Health report: #{child_id} → #{parent_id}: #{health}")

    # Emit telemetry
    :telemetry.execute(
      [:indrajaal, :holon, :health_report],
      %{},
      %{child_id: child_id, parent_id: parent_id, health: health}
    )

    :ok
  end

  @doc """
  Converts health to a numeric priority (higher = worse).
  """
  @spec health_priority(Holon.health()) :: non_neg_integer()
  def health_priority(health) do
    Enum.find_index(@health_order, &(&1 == health)) || 0
  end

  @doc """
  Converts numeric priority back to health status.
  """
  @spec priority_to_health(non_neg_integer()) :: Holon.health()
  def priority_to_health(priority) do
    Enum.at(@health_order, priority, :healthy)
  end

  # Private helpers

  defp vsm_failed?(vsm) do
    Map.get(vsm.s5, :violated, false)
  end

  defp vsm_critical?(vsm) do
    Map.get(vsm.s3, :over_budget, false) or
      Map.get(vsm.s1, :error_rate, 0) > 0.5
  end

  defp vsm_degraded?(vsm) do
    Map.get(vsm.s2, :oscillating, false) or
      Map.get(vsm.s1, :error_rate, 0) > 0.1
  end

  defp s1_status(s1), do: if(Map.get(s1, :error_rate, 0) > 0.1, do: :degraded, else: :ok)
  defp s2_status(s2), do: if(Map.get(s2, :oscillating, false), do: :oscillating, else: :ok)
  defp s3_status(s3), do: if(Map.get(s3, :over_budget, false), do: :over_budget, else: :ok)
  defp s4_status(s4), do: if(Map.get(s4, :confidence, 1.0) < 0.3, do: :low_confidence, else: :ok)
  defp s5_status(s5), do: if(Map.get(s5, :violated, false), do: :violated, else: :ok)
end
